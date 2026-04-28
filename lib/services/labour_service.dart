import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/labour_model.dart';

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

  void _logWrite(String collection, String operation, String docId) {
    debugPrint(
      '🔥 FIRESTORE | $collection | $operation | $docId | user: ${_auth.currentUser?.uid}',
    );
  }

  Future<void> addLabour(Labour labour) async {
    try {
      final uid = _requireUid();
      final oldLocalId = labour.id;

      labour.supervisorId = uid;
      labour.isSynced = false;

      await _labourBox.put(labour.id, labour);

      final docRef = await _db.collection('labours').add({
        'id': '',
        'supervisorId': uid,
        'name': labour.name,
        'phone': labour.phone,
        'dailyWage': labour.dailyWage,
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

      debugPrint('Labour added: ${labour.name}');
    } catch (e) {
      debugPrint('Labour sync failed: $e');
      rethrow;
    }
  }

  Future<void> updateLabour(Labour labour) async {
    final uid = _requireUid();
    labour.supervisorId = uid;
    labour.isSynced = false;
    await _labourBox.put(labour.id, labour);

    try {
      final docId = labour.firestoreId ?? labour.id;
      await _db.collection('labours').doc(docId).set({
        'id': docId,
        'supervisorId': uid,
        'name': labour.name,
        'phone': labour.phone,
        'dailyWage': labour.dailyWage,
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
    final items = _labourBox.values
        .where((l) => l.supervisorId == uid && l.isActive)
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<void> fetchAndSyncLabours() async {
    try {
      final uid = _requireUid();
      final snap = await _db
          .collection('labours')
          .where('supervisorId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        final labour = Labour.fromFirestore(doc);
        await _labourBox.put(labour.id, labour);
      }
      debugPrint('Synced ${snap.docs.length} labours from Firebase');
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

  List<Labour> searchLabours(String query) {
    return getLocalLabours()
        .where((l) => l.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
