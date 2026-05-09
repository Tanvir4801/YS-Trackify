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
        _attendanceBox =
            attendanceBox ?? Hive.box<Attendance>(Attendance.boxName),
        _labourBox = labourBox ?? Hive.box<Labour>(Labour.boxName);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Box<Attendance> _attendanceBox;
  final Box<Labour> _labourBox;

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw Exception('User not logged in');
    return uid;
  }

  /// Returns the contractorId that scopes all queries.
  /// Falls back to the supervisor UID so single-tenant setups work too.
  String _contractorScope(String uid) {
    final cached = SessionService.instance.contractorId;
    if (cached != null && cached.isNotEmpty) return cached;
    return uid;
  }

  void _logWrite(String collection, String operation, String docId) {
    debugPrint(
      '🔥 FIRESTORE | $collection | $operation | $docId'
      ' | user: ${_auth.currentUser?.uid}',
    );
  }

  // ─────────────────────────────────────────────────────────
  // FIX 1 — getLaboursForAttendance
  // BUG: bulkMarkAttendance only queried labourBox by supervisorId.
  //      If a labour was added via the website (contractorId field only)
  //      it would be missing from the list → attendance not marked for it.
  // FIX: Query Firestore for both fields and merge with Hive.
  // ─────────────────────────────────────────────────────────
  Future<List<Labour>> _getLaboursForSupervisor(String uid) async {
    final Map<String, Labour> merged = {};
    final contractorId = _contractorScope(uid);

    // 1. Load from Hive first (instant, offline-safe)
    for (final l in _labourBox.values) {
      if (l.supervisorId == uid && l.isActive) {
        merged[l.id] = l;
      }
    }

    // 2. Query Firestore by supervisorId
    try {
      final snap1 = await _db
          .collection('labours')
          .where('supervisorId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();
      for (final doc in snap1.docs) {
        final l = Labour.fromFirestore(doc);
        merged[l.id] = l;
        await _labourBox.put(l.id, l); // keep Hive in sync
      }
      debugPrint('Labours by supervisorId: ${snap1.docs.length}');
    } catch (e) {
      debugPrint('labours/supervisorId query failed: $e');
    }

    // 3. Query Firestore by contractorId (website uses this field)
    try {
      final snap2 = await _db
          .collection('labours')
          .where('contractorId', isEqualTo: contractorId)
          .where('isActive', isEqualTo: true)
          .get();
      for (final doc in snap2.docs) {
        final l = Labour.fromFirestore(doc);
        merged[l.id] = l;
        await _labourBox.put(l.id, l);
      }
      debugPrint('Labours by contractorId: ${snap2.docs.length}');
    } catch (e) {
      debugPrint('labours/contractorId query failed: $e');
    }

    debugPrint('Total unique labours for attendance: ${merged.length}');
    return merged.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ─────────────────────────────────────────────────────────
  // markAttendance — unchanged logic, keeps dual-write
  // ─────────────────────────────────────────────────────────
  Future<void> markAttendance(
    Attendance attendance, {
    String markedVia = 'manual',
  }) async {
    final uid          = _requireUid();
    final contractorId = _contractorScope(uid);

    if (attendance.labourId.trim().isEmpty) {
      throw Exception('labourId must not be empty');
    }

    attendance.supervisorId = uid;
    attendance.contractorId = contractorId;
    if (attendance.id.trim().isEmpty) {
      attendance.id = '${attendance.labourId}_${attendance.date}';
    }
    attendance.isSynced     = false;
    await _attendanceBox.put(attendance.id, attendance);

    debugPrint(
      '🔄 attendance markAttendance labourId=${attendance.labourId} '
      'date=${attendance.date} contractorId=${attendance.contractorId} '
      'supervisorId=${attendance.supervisorId} docId=${attendance.id}',
    );

    try {
      // ── Flat collection (legacy + current app queries) ──
      final docRef = _db.collection('attendance').doc(attendance.id);
      await docRef.set(attendance.toFirestore(), SetOptions(merge: true));
      _logWrite('attendance', 'SET', docRef.id);
      attendance.firestoreId = docRef.id;

      // ── Nested collection (new path) ──
      final nestedRef = FirestorePaths.attendanceRecordRef(
        contractorId,
        attendance.date,
        attendance.labourId,
      );
      await nestedRef.set({
        'labourId':      attendance.labourId,
        'contractorId':  contractorId,
        'supervisorId':  uid,
        'supervisorRef': FirestorePaths.userRef(uid),
        'date':          attendance.date,
        'status':        attendance.status.firestoreValue,
        'overtimeHours': attendance.overtimeHours,
        'markedVia':     markedVia,
        'markedAt':      FieldValue.serverTimestamp(),
        'legacyId':      docRef.id,
      }, SetOptions(merge: true));
      _logWrite(
        'attendance/$contractorId/dates/${attendance.date}/records',
        'SET',
        attendance.labourId,
      );

      // Stamp parent date doc
      await FirestorePaths
          .attendanceDateDoc(contractorId, attendance.date)
          .set({
        'date':        attendance.date,
        'contractorId': contractorId,
        'updatedAt':   FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      attendance.isSynced = true;
      await _attendanceBox.put(attendance.id, attendance);
    } catch (e) {
      debugPrint('Attendance sync failed: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // FIX 2 — bulkMarkAttendance
  // BUG: Only queried _labourBox by supervisorId.
  //      Missed labours added from website (contractorId only).
  // FIX: Use _getLaboursForSupervisor() which checks both fields.
  // ─────────────────────────────────────────────────────────
  Future<void> bulkMarkAttendance(String date, String status) async {
    final uid          = _requireUid();
    final parsedStatus = AttendanceStatusX.fromFirestoreValue(status);

    // Use fixed helper that queries both fields
    final labours = await _getLaboursForSupervisor(uid);

    debugPrint('Bulk marking ${labours.length} labours as $status on $date');

    for (final labour in labours) {
      final attendance = Attendance(
        id:           '${labour.id}_$date',
        labourId:     labour.id,
        supervisorId: uid,
        date:         date,
        status:       parsedStatus,
        overtimeHours: 0,
      );
      await markAttendance(attendance);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Local helpers (unchanged)
  // ─────────────────────────────────────────────────────────

  List<Attendance> getAttendanceForDate(String date) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return [];
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

  // ─────────────────────────────────────────────────────────
  // FIX 3 — fetchAttendanceForDate
  // BUG: Nested path fetch could fail silently and not fall
  //      back to flat collection, leaving attendanceMap empty.
  // FIX: Always fetch flat collection regardless of nested result.
  //      Also fetch by contractorId as fallback.
  // ─────────────────────────────────────────────────────────
  Future<void> fetchAttendanceForDate(String date) async {
    try {
      final uid          = _requireUid();
      final contractorId = _contractorScope(uid);
      final ids          = <String>{};

      // 1. Try nested path first (new structure)
      try {
        final nested = await FirestorePaths
            .attendanceRecordsCol(contractorId, date)
            .get();
        for (final doc in nested.docs) {
          final data = doc.data();
          final att  = Attendance(
            id:           '${data['labourId']}_$date',
            labourId:     (data['labourId']     as String?) ?? doc.id,
            supervisorId: (data['supervisorId'] as String?) ?? uid,
            contractorId: (data['contractorId'] as String?) ?? contractorId,
            date:         date,
            status:       AttendanceStatusX.fromFirestoreValue(
                            (data['status'] as String?) ?? 'absent'),
            overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
          )..isSynced = true;
          await _attendanceBox.put(att.id, att);
          ids.add(att.id);
        }
        debugPrint(
          'fetchAttendanceForDate nested: ${nested.docs.length} records');
      } catch (e) {
        debugPrint('nested fetchAttendanceForDate failed (non-fatal): $e');
      }

      // 2. Flat collection by supervisorId (always run)
      try {
        final snap1 = await _db
            .collection('attendance')
            .where('supervisorId', isEqualTo: uid)
            .where('date',         isEqualTo: date)
            .get();
        for (final doc in snap1.docs) {
          final att = Attendance.fromFirestore(doc);
          await _attendanceBox.put(att.id, att);
          ids.add(att.id);
        }
        debugPrint(
          'fetchAttendanceForDate flat/supervisorId: ${snap1.docs.length}');
      } catch (e) {
        debugPrint('flat/supervisorId fetch failed: $e');
      }

      // 3. Flat collection by contractorId (catches website-created records)
      try {
        final snap2 = await _db
            .collection('attendance')
          .where('contractorId', isEqualTo: contractorId)
            .where('date',         isEqualTo: date)
            .get();
        for (final doc in snap2.docs) {
          final att = Attendance.fromFirestore(doc);
          if (ids.contains(att.id)) continue;
          await _attendanceBox.put(att.id, att);
          ids.add(att.id);
        }
        debugPrint(
          'fetchAttendanceForDate flat/contractorId: ${snap2.docs.length}');
      } catch (e) {
        debugPrint('flat/contractorId fetch failed: $e');
      }

      debugPrint(
        'fetchAttendanceForDate total records loaded: ${ids.length}');
    } catch (e) {
      debugPrint('fetchAttendanceForDate error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // fetchAttendanceRange — unchanged + contractorId fallback
  // ─────────────────────────────────────────────────────────
  Future<void> fetchAttendanceRange(DateTime from, DateTime to) async {
    final fromStr = Attendance.formatDate(from);
    final toStr   = Attendance.formatDate(to);
    try {
      final uid = _requireUid();

      // By supervisorId
      final snap1 = await _db
          .collection('attendance')
          .where('supervisorId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: fromStr)
          .where('date', isLessThanOrEqualTo:    toStr)
          .get();
      for (final doc in snap1.docs) {
        await _attendanceBox.put(
          Attendance.fromFirestore(doc).id,
          Attendance.fromFirestore(doc),
        );
      }

      // By contractorId (catches website records)
      final contractorId = _contractorScope(uid);
      if (contractorId != uid) {
        final snap2 = await _db
            .collection('attendance')
            .where('contractorId', isEqualTo: contractorId)
            .where('date', isGreaterThanOrEqualTo: fromStr)
            .where('date', isLessThanOrEqualTo:    toStr)
            .get();
        for (final doc in snap2.docs) {
          final att = Attendance.fromFirestore(doc);
          await _attendanceBox.put(att.id, att);
        }
      }
    } catch (e) {
      debugPrint('fetchAttendanceRange failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Real-time stream — unchanged
  // ─────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> attendanceStreamForDate(String dateKey) {
    final uid          = _requireUid();
    final contractorId = _contractorScope(uid);
    return FirestorePaths.attendanceRecordsCol(contractorId, dateKey)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {...d.data(), 'docId': d.id}).toList());
  }

  // ─────────────────────────────────────────────────────────
  // FIX 4 — getLaboursForAttendance (public method)
  // Exposed so AttendanceProvider can also call it directly.
  // ─────────────────────────────────────────────────────────
  Future<List<Labour>> getLaboursForAttendance() async {
    final uid = _requireUid();
    return _getLaboursForSupervisor(uid);
  }

  // ─────────────────────────────────────────────────────────
  // cycleStatus — unchanged
  // ─────────────────────────────────────────────────────────
  String cycleStatus(String current) {
    switch (current) {
      case 'present': return 'absent';
      case 'absent':  return 'half';
      case 'half':    return 'present';
      default:        return 'present';
    }
  }
}
