import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/labour_model.dart';
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

  // ── helpers ──────────────────────────────────

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw Exception('User not logged in');
    return uid;
  }

  String _contractorScope(String uid) {
    final cached = SessionService.instance.contractorId;
    if (cached != null && cached.isNotEmpty) return cached;
    return uid;
  }

  void _log(String op, String docId) => debugPrint(
        '🔥 FIRESTORE | labours | $op | $docId | '
        'user:${_auth.currentUser?.uid}',
      );

  // ── ADD ──────────────────────────────────────

      labour.supervisorId = uid;
      labour.contractorId = contractorId;
      labour.isSynced = false;

    // 1. Save to Hive immediately (offline backup)
    labour.supervisorId = uid;
    labour.isSynced = false;
    await _labourBox.put(labour.id, labour);

    try {
      // 2. Write to Firestore
      final docRef = await _db.collection('labours').add({
        'supervisorId': uid,
        // Store as DocumentReference for admin panel compatibility
        'supervisorRef': _db.doc('users/$uid'),
        'contractorId': contractorId,
        'name': labour.name,
        'phone': labour.phone,
        'dailyWage': labour.dailyWage,
        'dailyRate': labour.dailyWage, // alias for admin panel
        'overtimeWagePerHour': labour.overtimeWagePerHour,
        'defaultOvertimeHours': labour.defaultOvertimeHours,
        'joiningDate': Timestamp.fromDate(labour.joiningDate),
        'skill': '',
        'isActive': true,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      });

      // 3. Update doc with its own ID
      await docRef.update({'id': docRef.id});
      _log('ADD', docRef.id);

      // 4. Update Hive with Firestore ID
      final oldId = labour.id;
      labour.id = docRef.id;
      labour.firestoreId = docRef.id;
      labour.isSynced = true;
      labour.lastSyncedAt = DateTime.now();
      labour.syncedAt = labour.lastSyncedAt;

      if (oldId != docRef.id) await _labourBox.delete(oldId);
      await _labourBox.put(labour.id, labour);

      debugPrint('Labour added: ${labour.name} | supervisor=$uid contractorId=$contractorId');
    } catch (e) {
      debugPrint('❌ Labour Firestore write failed: $e');
      rethrow;
    }
  }

  // ── UPDATE ───────────────────────────────────

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
        'supervisorRef': _db.doc('users/$uid'),
        'contractorId': contractorId,
        'name': labour.name,
        'phone': labour.phone,
        'dailyWage': labour.dailyWage,
        'dailyRate': labour.dailyWage,
        'overtimeWagePerHour': labour.overtimeWagePerHour,
        'defaultOvertimeHours': labour.defaultOvertimeHours,
        'joiningDate': Timestamp.fromDate(labour.joiningDate),
        'skill': '',
        'isActive': labour.isActive,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _log('UPDATE', docId);

      labour.firestoreId = docId;
      labour.isSynced = true;
      labour.lastSyncedAt = DateTime.now();
      labour.syncedAt = labour.lastSyncedAt;
      await _labourBox.put(labour.id, labour);
    } catch (e) {
      debugPrint('❌ Labour update failed: $e');
      rethrow;
    }
  }

  // ── DELETE ───────────────────────────────────

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
        _log('SOFT_DELETE', labour.firestoreId!);
        labour.isSynced = true;
        labour.lastSyncedAt = DateTime.now();
        labour.syncedAt = labour.lastSyncedAt;
        await _labourBox.put(labour.id, labour);
      }
    } catch (e) {
      debugPrint('❌ Labour delete failed: $e');
      rethrow;
    }
  }

  // ── READ LOCAL ───────────────────────────────

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

  // ── FETCH AND SYNC FROM FIRESTORE ────────────

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
        debugPrint('📥 supervisorId query: ${snap.docs.length} docs');
      } catch (e) {
        debugPrint('supervisorId query failed: $e');
      }

      for (final labour in merged.values) {
        await _labourBox.put(labour.id, labour);
      }
      debugPrint('Total unique labours fetched: ${merged.length}');
    } catch (e) {
      debugPrint('❌ fetchAndSyncLabours failed: $e');
      rethrow;
    }
  }

  // ── REAL-TIME STREAMS ────────────────────────

  /// PRIMARY stream — use this everywhere in UI.
  /// Tries supervisorRef first (admin panel compatible),
  /// falls back to supervisorId string.
  Stream<List<Labour>> labourStream() {
    final uid = _requireUid();
    return _db
        .collection('labours')
        .where('supervisorRef', isEqualTo: _db.doc('users/$uid'))
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) {
          final labours = snap.docs.map((d) {
            final l = Labour.fromFirestore(d);
            l.supervisorId = uid; // ensure local field is populated
            return l;
          }).toList();
          debugPrint('🔴 labourStream: ${labours.length} labours');
          return labours;
        });
  }

  /// Stream by contractorId — use for admin-panel-added labours
  /// that may not have supervisorRef set yet.
  Stream<List<Labour>> labourStreamByContractor() {
    final uid = _requireUid();
    final contractorId = _contractorScope(uid);

    return _db
        .collection('labours')
        .where('contractorId', isEqualTo: contractorId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) {
          final labours = snap.docs.map((d) {
            final l = Labour.fromFirestore(d);
            l.supervisorId = uid;
            return l;
          }).toList();
          debugPrint('🔴 labourStreamByContractor: ${labours.length} labours');
          return labours;
        });
  }

  // ── SEARCH ───────────────────────────────────

  List<Labour> searchLabours(String query) {
    return getLocalLabours()
        .where((l) => l.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
