import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/attendance_model.dart';
import '../models/labour_model.dart';
import '../models/payment_model.dart';
import 'connectivity_service.dart';

class SyncEngine {
  SyncEngine({
    FirebaseFirestore? firestore,
      FirebaseAuth? auth,
    ConnectivityService? connectivityService,
    Box<Labour>? labourBox,
    Box<Attendance>? attendanceBox,
    Box<Payment>? paymentBox,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
        _connectivityService = connectivityService ?? ConnectivityService(),
        _labourBox = labourBox ?? Hive.box<Labour>(Labour.boxName),
        _attendanceBox = attendanceBox ?? Hive.box<Attendance>(Attendance.boxName),
        _paymentBox = paymentBox ?? Hive.box<Payment>(Payment.boxName);

  final FirebaseFirestore _firestore;
    final FirebaseAuth _auth;
  final ConnectivityService _connectivityService;
  final Box<Labour> _labourBox;
  final Box<Attendance> _attendanceBox;
  final Box<Payment> _paymentBox;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceRealtimeSub;

  void _logWrite(String collection, String operation, String docId) {
    debugPrint(
      '🔥 FIRESTORE | $collection | $operation | $docId | user: ${_auth.currentUser?.uid}',
    );
  }

  Future<void> syncPendingRecords() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        return;
      }

      final online = await _connectivityService.isOnline();
      if (!online) {
        return;
      }

      final pendingLabours = _labourBox.values.where((x) => !x.isSynced).toList();
      for (final labour in pendingLabours) {
        if (labour.supervisorId.isEmpty) {
          labour.supervisorId = uid;
        }

        await retryWithBackoff(() async {
          final now = DateTime.now();

          if (labour.firestoreId != null && labour.firestoreId!.isNotEmpty) {
            final docRef = _firestore.collection('labours').doc(labour.firestoreId);
            await docRef.set(labour.toFirestore(), SetOptions(merge: true));
            _logWrite('labours', 'SET_MERGE', docRef.id);
          } else {
            final ref = await _firestore.collection('labours').add(labour.toFirestore());
            await ref.update({'id': ref.id});
            _logWrite('labours', 'ADD', ref.id);
            labour
              ..firestoreId = ref.id
              ..id = ref.id;
          }

          labour
            ..syncedAt = now
            ..lastSyncedAt = now
            ..isSynced = true;
          await labour.save();
        });
      }

      final pendingAttendance = _attendanceBox.values.where((x) => !x.isSynced).toList();
      for (final attendance in pendingAttendance) {
        if (attendance.supervisorId.isEmpty) {
          attendance.supervisorId = uid;
        }

        await retryWithBackoff(() async {
          final now = DateTime.now();

          if (attendance.firestoreId != null && attendance.firestoreId!.isNotEmpty) {
            final docRef = _firestore.collection('attendance').doc(attendance.firestoreId);
            await docRef.set(attendance.toFirestore(), SetOptions(merge: true));
            _logWrite('attendance', 'SET_MERGE', docRef.id);
          } else {
            final ref = await _firestore.collection('attendance').add(attendance.toFirestore());
            await ref.update({'id': ref.id});
            _logWrite('attendance', 'ADD', ref.id);
            attendance.firestoreId = ref.id;
          }

          attendance
            ..syncedAt = now
            ..lastSyncedAt = now
            ..isSynced = true;
          await attendance.save();
        });
      }

      final pendingPayments = _paymentBox.values.where((x) => !x.isSynced).toList();
      for (final payment in pendingPayments) {
        if (payment.supervisorId.isEmpty) {
          payment.supervisorId = uid;
        }

        await retryWithBackoff(() async {
          final now = DateTime.now();

          if (payment.firestoreId != null && payment.firestoreId!.isNotEmpty) {
            final docRef = _firestore.collection('payments').doc(payment.firestoreId);
            await docRef.set(payment.toFirestore(), SetOptions(merge: true));
            _logWrite('payments', 'SET_MERGE', docRef.id);
          } else {
            final ref = await _firestore.collection('payments').add(payment.toFirestore());
            await ref.update({'id': ref.id});
            _logWrite('payments', 'ADD', ref.id);
            payment.firestoreId = ref.id;
          }

          payment
            ..syncedAt = now
            ..lastSyncedAt = now
            ..isSynced = true;
          await payment.save();
        });
      }
    } catch (e, st) {
      debugPrint('syncPendingRecords failed: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> fetchAndUpdateLocalData(String supervisorId) async {
    try {
      final online = await _connectivityService.isOnline();
      if (!online) {
        return;
      }

      final labours = await _firestore
          .collection('labours')
          .where('supervisorId', isEqualTo: supervisorId)
          .get();
      for (final doc in labours.docs) {
        final data = doc.data();
        final local = _labourBox.get(data['id'] as String? ?? doc.id);
        if (local == null) {
          await _labourBox.put(
            data['id'] as String? ?? doc.id,
            Labour(
              id: data['id'] as String? ?? doc.id,
              supervisorId: data['supervisorId'] as String? ?? supervisorId,
              name: data['name'] as String? ?? '',
              phone: data['phone'] as String? ?? '',
              dailyWage: (data['dailyWage'] as num?)?.toDouble() ?? 0,
              joiningDate: (data['joiningDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isActive: data['isActive'] as bool? ?? true,
              syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
              isSynced: true,
              firestoreId: doc.id,
              lastSyncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
            ),
          );
        } else {
          await resolveConflict(local, data);
        }
      }

      final attendance = await _firestore
          .collection('attendance')
          .where('supervisorId', isEqualTo: supervisorId)
          .get();
      for (final doc in attendance.docs) {
        final data = doc.data();
        final id = data['id'] as String? ?? doc.id;
        final local = _attendanceBox.get(id);
        if (local == null) {
          await _attendanceBox.put(
            id,
            Attendance(
              id: id,
              labourId: data['labourId'] as String? ?? '',
              supervisorId: data['supervisorId'] as String? ?? supervisorId,
              date: data['date'] as String? ?? '',
              status: AttendanceStatusX.fromFirestoreValue(data['status'] as String?),
              overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
              notes: data['notes'] as String? ?? '',
              syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
              isSynced: true,
              firestoreId: doc.id,
              lastSyncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
            ),
          );
        } else {
          await resolveConflict(local, data);
        }
      }

      final payments = await _firestore
          .collection('payments')
          .where('supervisorId', isEqualTo: supervisorId)
          .get();
      for (final doc in payments.docs) {
        final data = doc.data();
        final id = data['id'] as String? ?? doc.id;
        final local = _paymentBox.get(id);
        if (local == null) {
          await _paymentBox.put(
            id,
            Payment(
              id: id,
              labourId: data['labourId'] as String? ?? '',
              supervisorId: data['supervisorId'] as String? ?? supervisorId,
              type: PaymentTypeX.fromFirestoreValue(data['type'] as String?),
              amount: (data['amount'] as num?)?.toDouble() ?? 0,
              date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
              notes: data['notes'] as String? ?? '',
              isSynced: true,
              syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
              firestoreId: doc.id,
              lastSyncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
            ),
          );
        } else {
          await resolveConflict(local, data);
        }
      }
    } catch (e, st) {
      debugPrint('fetchAndUpdateLocalData failed: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> resolveConflict(dynamic localRecord, Map firestoreData) async {
    final remoteSyncedAt = (firestoreData['syncedAt'] as Timestamp?)?.toDate();
    final localSyncedAt = localRecord.lastSyncedAt as DateTime?;

    final remoteIsNewer = remoteSyncedAt != null &&
        (localSyncedAt == null || remoteSyncedAt.isAfter(localSyncedAt));

    if (!remoteIsNewer) {
      return;
    }

    if (localRecord is Labour) {
      localRecord
        ..name = firestoreData['name'] as String? ?? localRecord.name
        ..phone = firestoreData['phone'] as String? ?? localRecord.phone
        ..dailyWage = (firestoreData['dailyWage'] as num?)?.toDouble() ?? localRecord.dailyWage
        ..isActive = firestoreData['isActive'] as bool? ?? localRecord.isActive
        ..syncedAt = remoteSyncedAt
        ..lastSyncedAt = remoteSyncedAt
        ..isSynced = true;
      await localRecord.save();
      return;
    }

    if (localRecord is Attendance) {
      localRecord
        ..status = AttendanceStatusX.fromFirestoreValue(firestoreData['status'] as String?)
        ..overtimeHours = (firestoreData['overtimeHours'] as num?)?.toDouble() ?? localRecord.overtimeHours
        ..notes = firestoreData['notes'] as String? ?? localRecord.notes
        ..syncedAt = remoteSyncedAt
        ..lastSyncedAt = remoteSyncedAt
        ..isSynced = true;
      await localRecord.save();
      return;
    }

    if (localRecord is Payment) {
      localRecord
        ..type = PaymentTypeX.fromFirestoreValue(firestoreData['type'] as String?)
        ..amount = (firestoreData['amount'] as num?)?.toDouble() ?? localRecord.amount
        ..date = (firestoreData['date'] as Timestamp?)?.toDate() ?? localRecord.date
        ..notes = firestoreData['notes'] as String? ?? localRecord.notes
        ..syncedAt = remoteSyncedAt
        ..lastSyncedAt = remoteSyncedAt
        ..isSynced = true;
      await localRecord.save();
    }
  }

  Future<void> retryWithBackoff(Future Function() operation) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        await operation();
        return;
      } catch (e) {
        if (attempt >= 3) {
          rethrow;
        }
        final waitSeconds = pow(2, attempt).toInt();
        await Future<void>.delayed(Duration(seconds: waitSeconds));
      }
    }
  }

  void startConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivityService.onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        unawaited(syncPendingRecords());
      }
    });
  }

  void startAttendanceRealtimeListener({
    required String supervisorId,
    required String todayDate,
  }) {
    _attendanceRealtimeSub?.cancel();

    _attendanceRealtimeSub = _firestore
        .collection('attendance')
        .where('supervisorId', isEqualTo: supervisorId)
        .where('date', isEqualTo: todayDate)
        .snapshots()
        .listen((snapshot) async {
      final online = await _connectivityService.isOnline();
      if (!online) {
        return;
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = data['id'] as String? ?? doc.id;
        final existing = _attendanceBox.get(id);
        if (existing == null) {
          await _attendanceBox.put(
            id,
            Attendance(
              id: id,
              labourId: data['labourId'] as String? ?? '',
              supervisorId: data['supervisorId'] as String? ?? '',
              date: data['date'] as String? ?? todayDate,
              status: AttendanceStatusX.fromFirestoreValue(data['status'] as String?),
              overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
              notes: data['notes'] as String? ?? '',
              syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
              isSynced: true,
              firestoreId: doc.id,
              lastSyncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
            ),
          );
        } else {
          await resolveConflict(existing, data);
        }
      }
    }, onError: (Object e, StackTrace st) {
      debugPrint('attendance realtime listener failed: $e');
      debugPrint(st.toString());
    });
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _attendanceRealtimeSub?.cancel();
  }
}
