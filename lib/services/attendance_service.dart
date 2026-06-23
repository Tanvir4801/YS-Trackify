import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

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

  void _logWrite(String col, String op, String docId) {
    debugPrint('🔥 FIRESTORE | $col | $op | $docId | user: ${_auth.currentUser?.uid}');
  }

  // ── _getLaboursForSupervisor ──────────────────────────────
  Future<List<Labour>> _getLaboursForSupervisor(String uid) async {
    final Map<String, Labour> merged = {};
    final contractorId = _contractorScope(uid);

    for (final l in _labourBox.values) {
      if (l.supervisorId == uid && l.isActive && !l.isTemporary) {
        merged[l.id] = l;
      }
    }

    try {
      final snap1 = await _db
          .collection('labours')
          .where('supervisorId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();
      for (final doc in snap1.docs) {
        final l = Labour.fromFirestore(doc);
        if (!l.isTemporary) {
          merged[l.id] = l;
          await _labourBox.put(l.id, l);
        }
      }
    } catch (e) {
      debugPrint('labours/supervisorId query failed: $e');
    }

    try {
      final snap2 = await _db
          .collection('labours')
          .where('contractorId', isEqualTo: contractorId)
          .where('isActive', isEqualTo: true)
          .get();
      for (final doc in snap2.docs) {
        final l = Labour.fromFirestore(doc);
        if (!l.isTemporary) {
          merged[l.id] = l;
          await _labourBox.put(l.id, l);
        }
      }
    } catch (e) {
      debugPrint('labours/contractorId query failed: $e');
    }

    return merged.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  // ── fetchAllContractorAttendanceForDate ───────────────────
  Future<Map<String, Attendance>> fetchAllContractorAttendanceForDate(String date) async {
    final uid = _requireUid();
    final contractorId = _contractorScope(uid);
    final Map<String, Attendance> result = {};

    try {
      final nested = await FirestorePaths.attendanceRecordsCol(contractorId, date).get();
      for (final doc in nested.docs) {
        final data = doc.data();
        final att = Attendance(
          id: '${data['labourId']}_$date',
          labourId: (data['labourId'] as String?) ?? doc.id,
          supervisorId: (data['supervisorId'] as String?) ?? uid,
          contractorId: (data['contractorId'] as String?) ?? contractorId,
          siteId: (data['siteId'] as String?) ?? (data['supervisorId'] as String?) ?? uid,
          date: date,
          status: AttendanceStatusX.fromFirestoreValue((data['status'] as String?) ?? 'absent'),
          overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
          remark: (data['remark'] as String?) ?? (data['notes'] as String?) ?? '',
          wageAtTime: (data['wageAtTime'] as num?)?.toDouble() ?? 0,
        )..isSynced = true;
        result[att.labourId] = att;
      }
    } catch (e) {
      debugPrint('fetchAllContractorAttendanceForDate nested failed: $e');
    }

    try {
      final snap = await _db
          .collection('attendance')
          .where('contractorId', isEqualTo: contractorId)
          .where('date', isEqualTo: date)
          .get();
      for (final doc in snap.docs) {
        final att = Attendance.fromFirestore(doc);
        if (!result.containsKey(att.labourId)) {
          result[att.labourId] = att;
        }
      }
    } catch (e) {
      debugPrint('fetchAllContractorAttendanceForDate flat failed: $e');
    }

    return result;
  }

  // ── markAttendance ────────────────────────────────────────
  Future<void> markAttendance(
    Attendance attendance, {
    String markedVia = 'manual',
    double wageAtTime = 0,
    String remark = '',
  }) async {
    final uid          = _requireUid();
    final contractorId = _contractorScope(uid);

    if (attendance.labourId.trim().isEmpty) {
      throw Exception('labourId must not be empty');
    }

    attendance.supervisorId = uid;
    attendance.contractorId = contractorId;
    // siteId is supplied by the caller from the tapped site card.
    // There is no permanent siteId on the labour document.
    attendance.wageAtTime = wageAtTime > 0 ? wageAtTime : attendance.wageAtTime;
    attendance.remark = remark.isNotEmpty ? remark : attendance.remark;
    if (attendance.remark.isNotEmpty) attendance.notes = attendance.remark;

    if (attendance.id.trim().isEmpty) {
      attendance.id = '${attendance.labourId}_${attendance.date}';
    }
    attendance.isSynced = false;
    await _attendanceBox.put(attendance.id, attendance);

    try {
      final flatPayload = attendance.toFirestore();
      final docRef = _db.collection('attendance').doc(attendance.id);
      await docRef.set(flatPayload, SetOptions(merge: true));
      _logWrite('attendance', 'SET', docRef.id);
      attendance.firestoreId = docRef.id;

      final nestedRef = FirestorePaths.attendanceRecordRef(
        contractorId,
        attendance.date,
        attendance.labourId,
      );
      await nestedRef.set({
        'labourId':      attendance.labourId,
        'contractorId':  contractorId,
        'supervisorId':  uid,
        'siteId':        attendance.siteId.isNotEmpty ? attendance.siteId : uid,
        'supervisorRef': FirestorePaths.userRef(uid),
        'date':          attendance.date,
        'status':        attendance.status.firestoreValue,
        'overtimeHours': attendance.overtimeHours,
        'remark':        attendance.remark,
        'wageAtTime':    attendance.wageAtTime,
        'markedVia':     markedVia,
        'markedAt':      FieldValue.serverTimestamp(),
        'legacyId':      docRef.id,
      }, SetOptions(merge: true));
      _logWrite('attendance/$contractorId/dates/${attendance.date}/records', 'SET', attendance.labourId);

      await FirestorePaths.attendanceDateDoc(contractorId, attendance.date).set({
        'date':         attendance.date,
        'contractorId': contractorId,
        'updatedAt':    FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      attendance.isSynced = true;
      await _attendanceBox.put(attendance.id, attendance);
    } catch (e) {
      debugPrint('Attendance sync failed: $e');
      rethrow;
    }
  }

  // ── addTemporaryLabour ────────────────────────────────────
  Future<Labour> addTemporaryLabour({
    required String name,
    required double dailyWage,
    required String date,
  }) async {
    final uid          = _requireUid();
    final contractorId = _contractorScope(uid);
    final id           = const Uuid().v4();

    final labour = Labour(
      id: id,
      supervisorId: uid,
      contractorId: contractorId,
      name: name,
      phone: '',
      dailyWage: dailyWage,
      joiningDate: DateTime.now(),
      isActive: true,
      type: LabourType.temporary,
    );

    await _labourBox.put(id, labour);

    try {
      await _db.collection('labours').doc(id).set(labour.toFirestore(), SetOptions(merge: true));
      debugPrint('✅ Temp labour created: $id ($name)');
    } catch (e) {
      debugPrint('Temp labour Firestore sync failed: $e');
    }

    return labour;
  }

  // ── updateAttendanceRemark ────────────────────────────────
  Future<void> updateAttendanceRemark(String labourId, String date, String remark) async {
    final uid = _requireUid();
    final contractorId = _contractorScope(uid);
    final id = '${labourId}_$date';

    final existing = _attendanceBox.get(id);
    if (existing != null) {
      existing.remark = remark;
      existing.notes = remark;
      await _attendanceBox.put(id, existing);
    }

    try {
      await _db.collection('attendance').doc(id).update({
        'remark': remark,
        'notes': remark,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('updateAttendanceRemark flat failed: $e');
    }

    try {
      final nestedRef = FirestorePaths.attendanceRecordRef(contractorId, date, labourId);
      await nestedRef.update({
        'remark': remark,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('updateAttendanceRemark nested failed: $e');
    }
  }

  // ── bulkMarkAttendance ────────────────────────────────────
  Future<void> bulkMarkAttendance(String date, String status) async {
    final uid          = _requireUid();
    final parsedStatus = AttendanceStatusX.fromFirestoreValue(status);
    final labours      = await _getLaboursForSupervisor(uid);

    for (final labour in labours) {
      final attendance = Attendance(
        id:           '${labour.id}_$date',
        labourId:     labour.id,
        supervisorId: uid,
        date:         date,
        status:       parsedStatus,
        overtimeHours: 0,
        wageAtTime:   labour.dailyWage,
        siteId:       uid,
      );
      await markAttendance(attendance, wageAtTime: labour.dailyWage);
    }
  }

  // ── Local helpers ─────────────────────────────────────────
  List<Attendance> getAttendanceForDate(String date) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return [];
    return _attendanceBox.values
        .where((a) => a.date == date && a.supervisorId == uid)
        .toList();
  }

  List<Attendance> getAllContractorAttendanceForDate(String date) {
    final uid          = _auth.currentUser?.uid;
    final contractorId = _contractorScope(uid ?? '');
    return _attendanceBox.values
        .where((a) =>
            a.date == date &&
            (a.contractorId == contractorId || a.supervisorId == uid))
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

  // ── fetchAttendanceForDate ────────────────────────────────
  Future<void> fetchAttendanceForDate(String date) async {
    try {
      final uid          = _requireUid();
      final contractorId = _contractorScope(uid);
      final ids          = <String>{};

      try {
        final nested = await FirestorePaths.attendanceRecordsCol(contractorId, date).get();
        for (final doc in nested.docs) {
          final data = doc.data();
          final att  = Attendance(
            id:           '${data['labourId']}_$date',
            labourId:     (data['labourId']     as String?) ?? doc.id,
            supervisorId: (data['supervisorId'] as String?) ?? uid,
            contractorId: (data['contractorId'] as String?) ?? contractorId,
            siteId:       (data['siteId'] as String?) ?? (data['supervisorId'] as String?) ?? uid,
            date:         date,
            status:       AttendanceStatusX.fromFirestoreValue((data['status'] as String?) ?? 'absent'),
            overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
            remark: (data['remark'] as String?) ?? (data['notes'] as String?) ?? '',
            wageAtTime: (data['wageAtTime'] as num?)?.toDouble() ?? 0,
          )..isSynced = true;
          await _attendanceBox.put(att.id, att);
          ids.add(att.id);
        }
      } catch (e) {
        debugPrint('nested fetchAttendanceForDate failed: $e');
      }

      try {
        final snap1 = await _db
            .collection('attendance')
            .where('supervisorId', isEqualTo: uid)
            .where('date', isEqualTo: date)
            .get();
        for (final doc in snap1.docs) {
          final att = Attendance.fromFirestore(doc);
          await _attendanceBox.put(att.id, att);
          ids.add(att.id);
        }
      } catch (e) {
        debugPrint('flat/supervisorId fetch failed: $e');
      }

      try {
        final snap2 = await _db
            .collection('attendance')
            .where('contractorId', isEqualTo: contractorId)
            .where('date', isEqualTo: date)
            .get();
        for (final doc in snap2.docs) {
          final att = Attendance.fromFirestore(doc);
          if (ids.contains(att.id)) continue;
          await _attendanceBox.put(att.id, att);
          ids.add(att.id);
        }
      } catch (e) {
        debugPrint('flat/contractorId fetch failed: $e');
      }

      debugPrint('fetchAttendanceForDate: ${ids.length} records for $date');
    } catch (e) {
      debugPrint('fetchAttendanceForDate error: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> attendanceStreamForDate(String dateKey) {
    final uid          = _requireUid();
    final contractorId = _contractorScope(uid);
    return FirestorePaths.attendanceRecordsCol(contractorId, dateKey)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {...d.data(), 'docId': d.id}).toList());
  }

  // ── applyAllowances ─────────────────────────────────────────
  /// Apply petrol/lunch/breakfast/tea to all PRESENT labours at siteId on date.
  /// Also writes a siteAllowances audit doc.
  Future<int> applyAllowances({
    required String siteId,
    required String date,
    required double petrol,
    required double lunch,
    required double breakfast,
    required double tea,
  }) async {
    final uid          = _requireUid();
    final contractorId = _contractorScope(uid);
    final totalAllowance = petrol + lunch + breakfast + tea;

    final records = _attendanceBox.values
        .where((a) =>
            a.date == date &&
            a.siteId == siteId &&
            a.status == AttendanceStatus.present)
        .toList();

    if (records.isEmpty) return 0;

    final batch = _db.batch();
    for (final att in records) {
      att.petrol    = petrol;
      att.lunch     = lunch;
      att.breakfast = breakfast;
      att.tea       = tea;
      await _attendanceBox.put(att.id, att);

      final payload = {
        'allowances': {'petrol': petrol, 'lunch': lunch, 'breakfast': breakfast, 'tea': tea},
        'totalAllowance': totalAllowance,
        'grandTotal': att.wageAtTime + totalAllowance - att.advance,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      try {
        batch.update(_db.collection('attendance').doc(att.id), payload);
      } catch (_) {}

      try {
        final nestedRef = FirestorePaths.attendanceRecordRef(contractorId, date, att.labourId);
        batch.update(nestedRef, payload);
      } catch (_) {}
    }
    await batch.commit();

    // Write audit doc
    await _db.collection('siteAllowances').doc('${date}_$siteId').set({
      'date':            date,
      'siteId':          siteId,
      'contractorId':    contractorId,
      'setBy':           uid,
      'setAt':           FieldValue.serverTimestamp(),
      'allowances':      {'petrol': petrol, 'lunch': lunch, 'breakfast': breakfast, 'tea': tea},
      'totalAllowance':  totalAllowance,
      'appliedToCount':  records.length,
    }, SetOptions(merge: true));

    return records.length;
  }

  // ── updateSingleLabourAllowances ─────────────────────────────
  /// Update allowances for ONE specific labour's attendance record.
  Future<void> updateSingleLabourAllowances({
    required String labourId,
    required String date,
    required double petrol,
    required double lunch,
    required double breakfast,
    required double tea,
    required double advance,
  }) async {
    final uid          = _requireUid();
    final contractorId = _contractorScope(uid);
    final id           = '${labourId}_$date';

    final att = _attendanceBox.get(id);
    if (att != null) {
      att.petrol    = petrol;
      att.lunch     = lunch;
      att.breakfast = breakfast;
      att.tea       = tea;
      att.advance   = advance;
      await _attendanceBox.put(id, att);
    }

    final totalAllowance = petrol + lunch + breakfast + tea;
    final wageAtTime     = att?.wageAtTime ?? 0;
    final grandTotal     = wageAtTime + totalAllowance - advance;

    final payload = {
      'allowances': {'petrol': petrol, 'lunch': lunch, 'breakfast': breakfast, 'tea': tea},
      'totalAllowance': totalAllowance,
      'advance':        advance,
      'grandTotal':     grandTotal,
      'updatedAt':      FieldValue.serverTimestamp(),
    };

    try { await _db.collection('attendance').doc(id).update(payload); } catch (e) {
      debugPrint('updateSingleLabourAllowances flat failed: $e');
    }
    try {
      await FirestorePaths.attendanceRecordRef(contractorId, date, labourId).update(payload);
    } catch (e) {
      debugPrint('updateSingleLabourAllowances nested failed: $e');
    }
  }

  // ── setAdvance ───────────────────────────────────────────────
  Future<void> setAdvance({
    required String labourId,
    required String date,
    required double amount,
  }) async {
    final uid          = _requireUid();
    final contractorId = _contractorScope(uid);
    final id = '${labourId}_$date';

    final att = _attendanceBox.get(id);
    if (att != null) {
      att.advance = amount;
      await _attendanceBox.put(id, att);
    }

    final payload = {
      'advance':    amount,
      'grandTotal': (att?.wageAtTime ?? 0) + (att?.totalAllowance ?? 0) - amount,
      'updatedAt':  FieldValue.serverTimestamp(),
    };
    try { await _db.collection('attendance').doc(id).update(payload); } catch (_) {}
    try {
      await FirestorePaths.attendanceRecordRef(contractorId, date, labourId).update(payload);
    } catch (_) {}

    // Write to advance ledger
    try {
      await _db.collection('advances').doc(labourId).collection('entries').add({
        'date':                 date,
        'amount':               amount,
        'siteId':               att?.siteId ?? '',
        'givenBy':              uid,
        'contractorId':         contractorId,
        'linkedAttendanceDate': date,
        'type':                 'daily',
        'recovered':            false,
        'createdAt':            FieldValue.serverTimestamp(),
      });
    } catch (_) {}
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
