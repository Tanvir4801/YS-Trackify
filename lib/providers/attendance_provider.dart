import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/attendance_model.dart';
import '../models/labour_model.dart';
import '../services/attendance_service.dart';
import '../services/session_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({AttendanceService? service})
      : _service = service ?? AttendanceService(),
        _labourBox = Hive.box<Labour>(Labour.boxName);

  final AttendanceService _service;
  final Box<Labour> _labourBox;

  DateTime selectedDate = DateTime.now();

  List<Labour> labours = <Labour>[];
  List<Labour> tempLabours = <Labour>[];

  Map<String, String> attendanceMap = <String, String>{};
  Map<String, double> overtimeMap = <String, double>{};
  Map<String, String> remarkMap = <String, String>{};
  Map<String, double> wageAtTimeMap = <String, double>{};
  Map<String, String> siteMap = <String, String>{};
  Map<String, double> allowancePetrolMap    = <String, double>{};
  Map<String, double> allowanceLunchMap     = <String, double>{};
  Map<String, double> allowanceBreakfastMap = <String, double>{};
  Map<String, double> allowanceTeaMap       = <String, double>{};
  Map<String, double> advanceMap            = <String, double>{};

  bool isLoading = false;
  String? error;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceStream;

  String get selectedDateStr => Attendance.formatDate(selectedDate);

  List<Labour> get unmarkedLabours =>
      labours.where((l) => !attendanceMap.containsKey(l.id)).toList();

  List<Labour> get markedLabours =>
      labours.where((l) => attendanceMap.containsKey(l.id)).toList();

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      error = 'Not logged in';
      isLoading = false;
      notifyListeners();
      return;
    }

    _loadLocalLabours(uid);
    _loadLocalAttendance();

    await _fetchLabours(uid);
    await _service.fetchAttendanceForDate(selectedDateStr);
    _loadLocalAttendance();
    _computePendingPool(uid);

    isLoading = false;
    notifyListeners();

    _startAttendanceStream(uid);
  }

  void _computePendingPool(String uid) {
    final markedIds = attendanceMap.keys.toSet();
    tempLabours = _labourBox.values
        .where((l) => l.isTemporary && l.isActive)
        .toList();
    notifyListeners();
  }

  void _startAttendanceStream(String uid) {
    _attendanceStream?.cancel();

    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;
    final date = selectedDateStr;

    _attendanceStream = db
        .collection('attendance')
        .where('contractorId', isEqualTo: contractorId)
        .where('date', isEqualTo: date)
        .snapshots()
        .listen((snap) {
      bool changed = false;
      for (final doc in snap.docs) {
        final data = doc.data();
        final labourId = (data['labourId'] as String?) ?? '';
        final status = _normalizeStatus((data['status'] as String?) ?? '');
        final ot = (data['overtimeHours'] as num?)?.toDouble() ?? 0;
        final remark = (data['remark'] as String?) ?? (data['notes'] as String?) ?? '';
        final wage = (data['wageAtTime'] as num?)?.toDouble() ?? 0;
        final site = (data['siteId'] as String?) ?? (data['supervisorId'] as String?) ?? '';

        if (labourId.isEmpty || status.isEmpty) continue;

        if (attendanceMap[labourId] != status) {
          attendanceMap[labourId] = status;
          changed = true;
        }
        if (ot > 0 && overtimeMap[labourId] != ot) {
          overtimeMap[labourId] = ot;
          changed = true;
        }
        if (remark.isNotEmpty && remarkMap[labourId] != remark) {
          remarkMap[labourId] = remark;
          changed = true;
        }
        if (wage > 0 && wageAtTimeMap[labourId] != wage) {
          wageAtTimeMap[labourId] = wage;
          changed = true;
        }
        if (site.isNotEmpty && siteMap[labourId] != site) {
          siteMap[labourId] = site;
          changed = true;
        }
      }
      if (changed) {
        _computePendingPool(uid);
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[AttendanceProvider] stream error: $e');
    });
  }

  String _normalizeStatus(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'half_day' || s == 'half-day') return 'half';
    if (s == 'present' || s == 'absent' || s == 'half') return s;
    return '';
  }

  void _loadLocalLabours(String uid) {
    final contractorId = SessionService.instance.contractorId ?? uid;
    labours = _labourBox.values.where((l) {
      if (!l.isActive) return false;
      if (l.isTemporary) return false;
      return l.supervisorId == uid ||
          l.contractorId == uid ||
          (contractorId.isNotEmpty && l.contractorId == contractorId);
    }).toList();
    labours.sort((a, b) => a.name.compareTo(b.name));

    tempLabours = _labourBox.values
        .where((l) => l.isTemporary && l.isActive)
        .toList();
  }

  Future<void> _fetchLabours(String uid) async {
    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;
    final Map<String, Labour> merged = {};

    for (final q in [
      db.collection('labours').where('supervisorId', isEqualTo: uid).where('isActive', isEqualTo: true).get(),
      db.collection('labours').where('contractorId', isEqualTo: uid).where('isActive', isEqualTo: true).get(),
      if (contractorId != uid && contractorId.isNotEmpty)
        db.collection('labours').where('contractorId', isEqualTo: contractorId).where('isActive', isEqualTo: true).get(),
    ]) {
      try {
        final s = await q;
        for (var d in s.docs) {
          merged[d.id] = Labour.fromFirestore(d);
        }
      } catch (e) {
        debugPrint('_fetchLabours query error: $e');
      }
    }

    for (final labour in merged.values) {
      await _labourBox.put(labour.id, labour);
    }

    labours = merged.values.where((l) => !l.isTemporary).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    tempLabours = merged.values.where((l) => l.isTemporary).toList();
    notifyListeners();
  }

  void _loadLocalAttendance() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final contractorId = SessionService.instance.contractorId ?? uid;

    final records = Hive.box<Attendance>(Attendance.boxName).values
        .where((a) =>
            a.date == selectedDateStr &&
            (a.contractorId == contractorId || a.supervisorId == uid))
        .toList();

    attendanceMap = {for (final a in records) a.labourId: a.status.firestoreValue};
    overtimeMap   = {for (final a in records) if (a.overtimeHours > 0) a.labourId: a.overtimeHours};
    remarkMap     = {for (final a in records) if (a.remark.isNotEmpty) a.labourId: a.remark};
    wageAtTimeMap = {for (final a in records) if (a.wageAtTime > 0) a.labourId: a.wageAtTime};
    siteMap              = {for (final a in records) if (a.siteId.isNotEmpty) a.labourId: a.siteId};
    allowancePetrolMap    = {for (final a in records) if (a.petrol > 0)    a.labourId: a.petrol};
    allowanceLunchMap     = {for (final a in records) if (a.lunch > 0)     a.labourId: a.lunch};
    allowanceBreakfastMap = {for (final a in records) if (a.breakfast > 0) a.labourId: a.breakfast};
    allowanceTeaMap       = {for (final a in records) if (a.tea > 0)       a.labourId: a.tea};
    advanceMap            = {for (final a in records) if (a.advance > 0)   a.labourId: a.advance};

    notifyListeners();
  }

  Future<void> _fetchFromFirebase() async {
    isLoading = true;
    notifyListeners();
    await _service.fetchAttendanceForDate(selectedDateStr);
    _loadLocalAttendance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _computePendingPool(uid);
    isLoading = false;
    notifyListeners();
  }

  Future<void> changeDate(DateTime newDate) async {
    selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
    _loadLocalAttendance();
    await _fetchFromFirebase();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) _startAttendanceStream(uid);
  }

  Future<void> markAttendance(String labourId, String status, {
    String remark = '',
    double? wageAtTimeOverride,
    String siteId = '',
  }) async {
    final existingOt = overtimeMap[labourId] ?? 0.0;
    final ot = status == 'absent' ? 0.0 : existingOt;

    double wageAtTime = wageAtTimeOverride ?? wageAtTimeMap[labourId] ?? 0.0;
    if (wageAtTime == 0) {
      final labour = _labourBox.get(labourId);
      wageAtTime = labour?.dailyWage ?? 0.0;
    }

    // siteId comes from whichever site card the supervisor tapped —
    // it is NOT stored on the labour document.
    final resolvedSiteId = siteId.isNotEmpty ? siteId : (siteMap[labourId] ?? '');

    final att = Attendance(
      id: '${labourId}_$selectedDateStr',
      labourId: labourId,
      supervisorId: FirebaseAuth.instance.currentUser!.uid,
      date: selectedDateStr,
      status: AttendanceStatusX.fromFirestoreValue(status),
      overtimeHours: ot,
      wageAtTime: wageAtTime,
      remark: remark.isNotEmpty ? remark : (remarkMap[labourId] ?? ''),
      siteId: resolvedSiteId,
    );

    await _service.markAttendance(att, wageAtTime: wageAtTime, remark: att.remark);

    attendanceMap[labourId] = status;
    wageAtTimeMap[labourId] = wageAtTime;
    if (resolvedSiteId.isNotEmpty) siteMap[labourId] = resolvedSiteId;
    if (ot > 0) {
      overtimeMap[labourId] = ot;
    } else {
      overtimeMap.remove(labourId);
    }
    if (remark.isNotEmpty) remarkMap[labourId] = remark;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _computePendingPool(uid);
    notifyListeners();
  }

  Future<void> setOvertime(String labourId, double hours) async {
    final safe = hours.isFinite && hours > 0 ? hours : 0.0;
    final status = attendanceMap[labourId] ?? 'present';
    final wageAtTime = wageAtTimeMap[labourId] ?? 0.0;
    final remark = remarkMap[labourId] ?? '';
    // Site is already recorded in siteMap from when attendance was first marked
    final resolvedSiteId = siteMap[labourId] ?? '';

    final att = Attendance(
      id: '${labourId}_$selectedDateStr',
      labourId: labourId,
      supervisorId: FirebaseAuth.instance.currentUser!.uid,
      date: selectedDateStr,
      status: AttendanceStatusX.fromFirestoreValue(status),
      overtimeHours: safe,
      wageAtTime: wageAtTime,
      remark: remark,
      siteId: resolvedSiteId,
    );
    await _service.markAttendance(att, wageAtTime: wageAtTime, remark: remark);

    attendanceMap[labourId] = status;
    if (safe > 0) {
      overtimeMap[labourId] = safe;
    } else {
      overtimeMap.remove(labourId);
    }
    notifyListeners();
  }

  Future<void> setRemark(String labourId, String remark) async {
    remarkMap[labourId] = remark;
    notifyListeners();

    final status = attendanceMap[labourId];
    if (status != null) {
      await _service.updateAttendanceRemark(labourId, selectedDateStr, remark);
    }
  }

  Future<void> addTempLabour({
    required String name,
    required double dailyWage,
  }) async {
    final labour = await _service.addTemporaryLabour(
      name: name,
      dailyWage: dailyWage,
      date: selectedDateStr,
    );
    tempLabours.add(labour);
    notifyListeners();
    await markAttendance(labour.id, 'present', wageAtTimeOverride: dailyWage);
  }

  Future<int> applyAllowances({
    required String siteId,
    required double petrol,
    required double lunch,
    required double breakfast,
    required double tea,
  }) async {
    final count = await _service.applyAllowances(
      siteId: siteId,
      date: selectedDateStr,
      petrol: petrol,
      lunch: lunch,
      breakfast: breakfast,
      tea: tea,
    );
    _loadLocalAttendance();
    return count;
  }

  Future<void> setAdvance(String labourId, double amount) async {
    advanceMap[labourId] = amount;
    notifyListeners();
    await _service.setAdvance(
      labourId: labourId,
      date: selectedDateStr,
      amount: amount,
    );
    _loadLocalAttendance();
  }

  Future<void> cycleStatus(String labourId) async {
    final current = attendanceMap[labourId] ?? 'absent';
    final next = _service.cycleStatus(current);
    await markAttendance(labourId, next);
  }

  Future<void> bulkMark(String status) async {
    await _service.bulkMarkAttendance(selectedDateStr, status);
    await initialize();
  }

  @override
  void dispose() {
    _attendanceStream?.cancel();
    super.dispose();
  }
}
