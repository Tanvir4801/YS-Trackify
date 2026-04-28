import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/result.dart';
import '../models/payment_model.dart';

class PaymentService {
  PaymentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Box<Payment>? paymentBox,
    Future<void> Function()? requestSync,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _paymentBox = paymentBox ?? Hive.box<Payment>(Payment.boxName),
        _requestSync = requestSync;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Box<Payment> _paymentBox;
  final Future<void> Function()? _requestSync;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('User not logged in');
    }
    return uid;
  }

  void _logWrite(String collection, String operation, String docId) {
    debugPrint(
      '🔥 FIRESTORE | $collection | $operation | $docId | user: ${_auth.currentUser?.uid}',
    );
  }

  Future<Result<Payment>> addPayment(Payment payment) async {
    try {
      if (payment.labourId.trim().isEmpty) {
        return Result.err(
          const AppFailure(message: 'labourId must not be empty'),
        );
      }

      final uid = _requireUid();
      var dirty = payment.copyWith(
        supervisorId: uid,
        isSynced: false,
      );

      await _paymentBox.put(dirty.id, dirty);

      try {
        final docRef = await _firestore.collection('payments').add({
          'id': '',
          'labourId': dirty.labourId,
          'supervisorId': uid,
          'type': dirty.type.firestoreValue,
          'amount': dirty.amount,
          'date': Timestamp.fromDate(dirty.date),
          'notes': dirty.notes,
          'isSynced': true,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        _logWrite('payments', 'ADD', docRef.id);

        await docRef.update({'id': docRef.id});
        _logWrite('payments', 'UPDATE_ID', docRef.id);

        if (dirty.id != docRef.id) {
          await _paymentBox.delete(dirty.id);
        }

        dirty = dirty.copyWith(
          id: docRef.id,
          firestoreId: docRef.id,
          isSynced: true,
          syncedAt: DateTime.now(),
          lastSyncedAt: DateTime.now(),
        );

        await _paymentBox.put(dirty.id, dirty);
        return Result.success(dirty);
      } catch (e) {
        debugPrint('addPayment firestore write failed, queued for sync: $e');
        unawaited(_requestSync?.call());
        return Result.success(dirty);
      }
    } catch (e, st) {
      debugPrint('addPayment failed: $e');
      return Result.err(
        AppFailure(message: 'Failed to add payment', exception: e, stackTrace: st),
      );
    }
  }

  Future<Result<List<Payment>>> getPayments(String labourId) async {
    try {
      final items = _paymentBox.values.where((p) => p.labourId == labourId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return Result.success(items);
    } catch (e, st) {
      debugPrint('getPayments failed: $e');
      return Result.err(
        AppFailure(message: 'Failed to read payments', exception: e, stackTrace: st),
      );
    }
  }

  Future<Result<double>> getAdvanceBalance(String labourId) async {
    try {
      final advances = _paymentBox.values.where(
        (p) => p.labourId == labourId && p.type == PaymentType.advance,
      );
      final total = advances.fold<double>(0, (runningTotal, item) => runningTotal + item.amount);
      return Result.success(total);
    } catch (e, st) {
      debugPrint('getAdvanceBalance failed: $e');
      return Result.err(
        AppFailure(message: 'Failed to compute advance balance', exception: e, stackTrace: st),
      );
    }
  }
}
