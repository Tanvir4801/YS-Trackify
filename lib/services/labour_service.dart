import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/labour_model.dart';
import 'firestore_paths.dart';
import 'session_service.dart';

class LabourService {
  LabourService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Box<Labour>? labourBox,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _labourBox = labourBox ?? Hive.box<Labour>(Labour.boxName);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Box<Labour> _labourBox;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('User not logged in');
    }
    return uid;
  }

  /// Resolves the contractor scope for queries/writes.
  ///
  /// Falls back to the supervisor uid when no SessionService user is cached
  /// (e.g. legacy supervisor account whose user doc has no contractorId yet).
  String _contractorScope(String uid) {
    final cached = SessionService.instance.contractorId;
    if (cached != null && cached.isNotEmpty) return cached;
    return uid;
  }

  void _logWrite(String collection, String operation, String docId) {
    debugPrint(
      '🔥 FIRESTORE | $collection | $operation | $docId | user: ${_auth.currentUser?.uid}',
    );
  }

  Future<void> addLabour(Labour labour) async {
    try {
      final uid = _requireUid();
      final contractorId = _contractorScope(uid);
      final oldLocalId = labour.id;

      labour.supervisorId = uid;
      labour.contractorId = contractorId;
      labour.isSynced = false;

      await _labourBox.put(labour.id, labour);

      final docRef = await _db.collection('labours').add({
        'id': '',
        'supervisorId': uid,
        'supervisorRef': FirestorePaths.userRef(uid),
        'contractorId': contractorId,
        'name': labour.name,
        'phone': labour.phone,
        'dailyWage': labour.dailyWage,
        'overtimeWagePerHour': labour.overtimeWagePerHour,
        'defaultOvertimeHours': labour.defaultOvertimeHours,
        'joiningDate': Timestamp.fromDate(labour.joiningDate),
        'isActive': true,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      });
      _logWrite('labours', 'ADD', docRef.id);

      await docRef.update({'id': docRef.id});
      _logWrite('labours', 'UPDATE_ID', docRef.id);

      if (oldLocalId != docRef.id) {
        await _labourBox.delete(oldLocalId);
        labour.id = docRef.id;
      }

      labour.firestoreId = docRef.id;
      labour.isSynced = true;
      labour.lastSyncedAt = DateTime.now();
      labour.syncedAt = labour.lastSyncedAt;
      await _labourBox.put(labour.id, labour);

      debugPrint('Labour added: ${labour.name} | supervisor=$uid contractorId=$contractorId');
    } catch (e) {
      debugPrint('Labour sync failed: $e');
      rethrow;
    }
  }

  Future<void> updateLabour(Labour labour) async {
    final uid = _requireUid();
    final contractorId = _contractorScope(uid);
    labour.supervisorId = uid;
    labour.contractorId = contractorId;
    labour.isSynced = false;
    await _labourBox.put(labour.id, labour);

    try {
      final docId = labour.firestoreId ?? labour.id;
      await _db.collection('labours').doc(docId).set({
        'id': docId,
        'supervisorId': uid,
        'supervisorRef': FirestorePaths.userRef(uid),
        'contractorId': contractorId,
        'name': labour.name,
        'phone': labour.phone,
        'dailyWage': labour.dailyWage,
        'overtimeWagePerHour': labour.overtimeWagePerHour,
        'defaultOvertimeHours': labour.defaultOvertimeHours,
        'joiningDate': Timestamp.fromDate(labour.joiningDate),
        'isActive': labour.isActive,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _logWrite('labours', 'UPDATE', docId);

      labour.firestoreId = docId;
      labour.isSynced = true;
      labour.lastSyncedAt = DateTime.now();
      labour.syncedAt = labour.lastSyncedAt;
      await _labourBox.put(labour.id, labour);
    } catch (e) {
      debugPrint('Labour update sync failed: $e');
      rethrow;
    }
  }

  Future<void> deleteLabour(Labour labour) async {
    _requireUid();
    labour.isActive = false;
    labour.isSynced = false;
    await _labourBox.put(labour.id, labour);

    try {
      if (labour.firestoreId != null) {
        await _db.collection('labours').doc(labour.firestoreId).update({
          'isActive': false,
          'isSynced': true,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        _logWrite('labours', 'SOFT_DELETE', labour.firestoreId!);
        labour.isSynced = true;
        labour.lastSyncedAt = DateTime.now();
        labour.syncedAt = labour.lastSyncedAt;
        await _labourBox.put(labour.id, labour);
      }
    } catch (e) {
      debugPrint('Labour delete sync failed: $e');
      rethrow;
    }
  }

  List<Labour> getLocalLabours() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return <Labour>[];
    }
    final contractorId = _contractorScope(uid);
    final items = _labourBox.values
        .where((l) {
          if (!l.isActive) return false;
          return l.supervisorId == uid ||
              l.contractorId == uid ||
              (contractorId.isNotEmpty && l.contractorId == contractorId);
        })
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<void> fetchAndSyncLabours() async {
    try {
      final uid = _requireUid();
      final contractorId = _contractorScope(uid);

      final Map<String, Labour> merged = {};

      debugPrint('Fetching labours for uid=$uid contractorId=$contractorId');

      // Query 1: by supervisorId (always present on all docs)
      try {
        final bySupervisor = await _db
            .collection('labours')
            .where('supervisorId', isEqualTo: uid)
            .where('isActive', isEqualTo: true)
            .get();
        for (final d in bySupervisor.docs) {
          merged[d.id] = Labour.fromFirestore(d);
        }
        debugPrint('By supervisorId: ${bySupervisor.docs.length}');
      } catch (e) {
        debugPrint('supervisorId labour query failed: $e');
      }

      // Query 2: by contractorId = uid (legacy supervisor-as-contractor)
      try {
        final byContractorUid = await _db
            .collection('labours')
            .where('contractorId', isEqualTo: uid)
            .where('isActive', isEqualTo: true)
            .get();
        for (final d in byContractorUid.docs) {
          merged[d.id] = Labour.fromFirestore(d);
        }
        debugPrint('By contractorId (uid): ${byContractorUid.docs.length}');
      } catch (e) {
        debugPrint('contractorId(uid) labour query failed: $e');
      }

      // Query 3: by contractorId from session (if different from uid)
      if (contractorId != uid && contractorId.isNotEmpty) {
        try {
          final byContractor = await _db
              .collection('labours')
              .where('contractorId', isEqualTo: contractorId)
              .where('isActive', isEqualTo: true)
              .get();
          for (final d in byContractor.docs) {
            merged[d.id] = Labour.fromFirestore(d);
          }
          debugPrint('By contractorId (session): ${byContractor.docs.length}');
        } catch (e) {
          debugPrint('contractorId(session) labour query failed: $e');
        }
      }

      for (final labour in merged.values) {
        await _labourBox.put(labour.id, labour);
      }
      debugPrint('Total unique labours fetched: ${merged.length}');
    } catch (e) {
      debugPrint('Fetch labours failed: $e - using local data');
      rethrow;
    }
  }

  Stream<List<Labour>> labourStream() {
    final uid = _requireUid();
    return _db
        .collection('labours')
        .where('supervisorId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Labour.fromFirestore).toList());
  }

  /// Newer-style stream filtered purely by contractorId. Use this when the
  /// caller is sure their data is migrated.
  Stream<List<Labour>> labourStreamByContractor() {
    final uid = _requireUid();
    final contractorId = _contractorScope(uid);
    return _db
        .collection('labours')
        .where('contractorId', isEqualTo: contractorId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Labour.fromFirestore).toList());
  }

  List<Labour> searchLabours(String query) {
    return getLocalLabours()
        .where((l) => l.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
