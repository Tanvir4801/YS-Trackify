import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/attendance_model.dart';
import '../models/labour_model.dart';

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

  void _logWrite(String collection, String operation, String docId) {
    debugPrint(
      '🔥 FIRESTORE | $collection | $operation | $docId | user: ${_auth.currentUser?.uid}',
    );
  }

  Future<void> markAttendance(Attendance attendance) async {
    final uid = _requireUid();
    if (attendance.labourId.trim().isEmpty) {
      throw Exception('labourId must not be empty');
    }

    attendance.supervisorId = uid;
    attendance.isSynced = false;

    await _attendanceBox.put(attendance.id, attendance);

    try {
      final existing = await _db
          .collection('attendance')
          .where('labourId', isEqualTo: attendance.labourId)
          .where('date', isEqualTo: attendance.date)
          .where('supervisorId', isEqualTo: uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'status': attendance.status.firestoreValue,
          'overtimeHours': attendance.overtimeHours,
          'isSynced': true,
          'supervisorId': uid,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        _logWrite('attendance', 'UPDATE', existing.docs.first.id);
        attendance.firestoreId = existing.docs.first.id;
      } else {
        final docRef = await _db.collection('attendance').add({
          'id': '',
          'labourId': attendance.labourId,
          'supervisorId': uid,
          'date': attendance.date.toString(),
          'status': attendance.status.firestoreValue,
          'overtimeHours': attendance.overtimeHours,
          'isSynced': true,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        _logWrite('attendance', 'ADD', docRef.id);
        await docRef.update({'id': docRef.id});
        _logWrite('attendance', 'UPDATE_ID', docRef.id);
        attendance.firestoreId = docRef.id;
      }
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
      final snap = await _db
          .collection('attendance')
          .where('supervisorId', isEqualTo: uid)
          .where('date', isEqualTo: date)
          .get();

      for (final doc in snap.docs) {
        final att = Attendance.fromFirestore(doc);
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
