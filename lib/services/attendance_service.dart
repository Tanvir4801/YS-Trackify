import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/attendance_model.dart';
import '../models/labour_model.dart';
import 'firestore_paths.dart';
import 'session_service.dart';

class AttendanceService {
  AttendanceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Box<Attendance>? attendanceBox,
    Box<Labour>? labourBox,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _attendanceBox = attendanceBox ?? Hive.box<Attendance>(Attendance.boxName),
        _labourBox = labourBox ?? Hive.box<Labour>(Labour.boxName);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Box<Attendance> _attendanceBox;
  final Box<Labour> _labourBox;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('User not logged in');
    }
    return uid;
  }

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

  Future<void> markAttendance(Attendance attendance, {String markedVia = 'manual'}) async {
    final uid = _requireUid();
    final contractorId = _contractorScope(uid);
    if (attendance.labourId.trim().isEmpty) {
      throw Exception('labourId must not be empty');
    }

    attendance.supervisorId = uid;
    attendance.isSynced = false;

    await _attendanceBox.put(attendance.id, attendance);

    try {
      // 1) Legacy flat write (for backward compatibility with old screens).
      final existing = await _db
          .collection('attendance')
          .where('labourId', isEqualTo: attendance.labourId)
          .where('date', isEqualTo: attendance.date)
          .where('supervisorId', isEqualTo: uid)
          .limit(1)
          .get();

      String legacyId;
      if (existing.docs.isNotEmpty) {
        legacyId = existing.docs.first.id;
        await existing.docs.first.reference.update({
          'status': attendance.status.firestoreValue,
          'overtimeHours': attendance.overtimeHours,
          'isSynced': true,
          'supervisorId': uid,
          'contractorId': contractorId,
          'markedVia': markedVia,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        _logWrite('attendance', 'UPDATE', legacyId);
      } else {
        final docRef = await _db.collection('attendance').add({
          'id': '',
          'labourId': attendance.labourId,
          'supervisorId': uid,
          'supervisorRef': FirestorePaths.userRef(uid),
          'contractorId': contractorId,
          'date': attendance.date.toString(),
          'status': attendance.status.firestoreValue,
          'overtimeHours': attendance.overtimeHours,
          'markedVia': markedVia,
          'isSynced': true,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        legacyId = docRef.id;
        _logWrite('attendance', 'ADD', legacyId);
        await docRef.update({'id': legacyId});
        _logWrite('attendance', 'UPDATE_ID', legacyId);
      }
      attendance.firestoreId = legacyId;

      // 2) New nested write: attendance/{contractorId}/dates/{dateKey}/records/{labourId}
      final nestedRef = FirestorePaths.attendanceRecordRef(
        contractorId,
        attendance.date,
        attendance.labourId,
      );
      await nestedRef.set({
        'labourId': attendance.labourId,
        'contractorId': contractorId,
        'supervisorId': uid,
        'supervisorRef': FirestorePaths.userRef(uid),
        'date': attendance.date,
        'status': attendance.status.firestoreValue,
        'overtimeHours': attendance.overtimeHours,
        'markedVia': markedVia,
        'markedAt': FieldValue.serverTimestamp(),
        'legacyId': legacyId,
      }, SetOptions(merge: true));
      _logWrite('attendance/$contractorId/dates/${attendance.date}/records',
          'SET', attendance.labourId);

      // Stamp the parent date doc so the dates collection is queryable.
      await FirestorePaths.attendanceDateDoc(contractorId, attendance.date).set({
        'date': attendance.date,
        'contractorId': contractorId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      attendance.isSynced = true;
      await _attendanceBox.put(attendance.id, attendance);
    } catch (e) {
      debugPrint('Attendance sync failed: $e');
      rethrow;
    }
  }

  Future<void> bulkMarkAttendance(String date, String status) async {
    final uid = _requireUid();
    final parsedStatus = AttendanceStatusX.fromFirestoreValue(status);
    final labours = _labourBox.values
        .where((l) => l.supervisorId == uid && l.isActive)
        .toList();

    for (final labour in labours) {
      final attendance = Attendance(
        id: '${labour.id}_$date',
        labourId: labour.id,
        supervisorId: uid,
        date: date,
        status: parsedStatus,
        overtimeHours: 0,
      );
      await markAttendance(attendance);
    }
  }

  List<Attendance> getAttendanceForDate(String date) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return <Attendance>[];
    }
    return _attendanceBox.values
        .where((a) => a.date == date && a.supervisorId == uid)
        .toList();
  }

  String? getStatusForLabour(String labourId, String date) {
    try {
      return _attendanceBox.values
          .firstWhere((a) => a.labourId == labourId && a.date == date)
          .status
          .firestoreValue;
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchAttendanceForDate(String date) async {
    try {
      final uid = _requireUid();
      final contractorId = _contractorScope(uid);
      final ids = <String>{};

      // Try the new nested path first.
      try {
        final nested = await FirestorePaths
            .attendanceRecordsCol(contractorId, date)
            .get();
        for (final doc in nested.docs) {
          final data = doc.data();
          final att = Attendance(
            id: '${data['labourId']}_$date',
            labourId: (data['labourId'] as String?) ?? doc.id,
            supervisorId: (data['supervisorId'] as String?) ?? uid,
            date: date,
            status: AttendanceStatusX.fromFirestoreValue(
                (data['status'] as String?) ?? 'absent'),
            overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
          )..isSynced = true;
          await _attendanceBox.put(att.id, att);
          ids.add(att.id);
        }
      } catch (e) {
        debugPrint('nested fetchAttendanceForDate failed: $e');
      }

      // Always also pull legacy docs so older data still flows in.
      final snap = await _db
          .collection('attendance')
          .where('supervisorId', isEqualTo: uid)
          .where('date', isEqualTo: date)
          .get();

      for (final doc in snap.docs) {
        final att = Attendance.fromFirestore(doc);
        if (ids.contains(att.id)) continue;
        await _attendanceBox.put(att.id, att);
      }
    } catch (e) {
      debugPrint('Fetch attendance failed: $e');
    }
  }

  Future<void> fetchAttendanceRange(DateTime from, DateTime to) async {
    final fromStr = Attendance.formatDate(from);
    final toStr = Attendance.formatDate(to);
    try {
      final uid = _requireUid();
      final snap = await _db
          .collection('attendance')
          .where('supervisorId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: fromStr)
          .where('date', isLessThanOrEqualTo: toStr)
          .get();
      for (final doc in snap.docs) {
        final att = Attendance.fromFirestore(doc);
        await _attendanceBox.put(att.id, att);
      }
    } catch (e) {
      debugPrint('Fetch range failed: $e');
    }
  }

  /// Real-time stream of attendance records for a single date (new path).
  Stream<List<Map<String, dynamic>>> attendanceStreamForDate(String dateKey) {
    final uid = _requireUid();
    final contractorId = _contractorScope(uid);
    return FirestorePaths.attendanceRecordsCol(contractorId, dateKey)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'docId': d.id}).toList());
  }

  String cycleStatus(String current) {
    switch (current) {
      case 'present':
        return 'absent';
      case 'absent':
        return 'half';
      case 'half':
        return 'present';
      default:
        return 'present';
    }
  }
}
