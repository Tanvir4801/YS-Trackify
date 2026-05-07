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
  Map<String, String> attendanceMap = <String, String>{};
  Map<String, double> overtimeMap = <String, double>{};
  bool isLoading = false;
  String? error;

  String get selectedDateStr => Attendance.formatDate(selectedDate);

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

    // Load from Hive first for instant display
    _loadLocalLabours(uid);
    _loadLocalAttendance();

    // Then fetch fresh data from Firebase
    await _fetchLabours(uid);
    await _service.fetchAttendanceForDate(selectedDateStr);
    _loadLocalAttendance();

    isLoading = false;
    notifyListeners();
  }

  void _loadLocalLabours(String uid) {
    final contractorId = SessionService.instance.contractorId ?? uid;
    labours = _labourBox.values.where((l) {
      if (!l.isActive) return false;
      return l.supervisorId == uid ||
          l.contractorId == uid ||
          (contractorId.isNotEmpty && l.contractorId == contractorId);
    }).toList();
    labours.sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _fetchLabours(String uid) async {
    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;
    final Map<String, Labour> merged = {};

    // Query by supervisorId
    try {
      final s = await db
          .collection('labours')
          .where('supervisorId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();
      for (var d in s.docs) {
        merged[d.id] = Labour.fromFirestore(d);
      }
    } catch (e) {
      debugPrint('att labours supervisorId: $e');
    }

    // Query by contractorId = uid
    try {
      final s = await db
          .collection('labours')
          .where('contractorId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();
      for (var d in s.docs) {
        merged[d.id] = Labour.fromFirestore(d);
      }
    } catch (e) {
      debugPrint('att labours contractorId(uid): $e');
    }

    // Query by contractorId from session
    if (contractorId != uid && contractorId.isNotEmpty) {
      try {
        final s = await db
            .collection('labours')
            .where('contractorId', isEqualTo: contractorId)
            .where('isActive', isEqualTo: true)
            .get();
        for (var d in s.docs) {
          merged[d.id] = Labour.fromFirestore(d);
        }
      } catch (e) {
        debugPrint('att labours contractorId(session): $e');
      }
    }

    // Save to Hive
    for (final labour in merged.values) {
      await _labourBox.put(labour.id, labour);
    }

    labours = merged.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    debugPrint('AttendanceProvider labours loaded: ${labours.length}');
    notifyListeners();
  }

  void _loadLocalAttendance() {
    final records = _service.getAttendanceForDate(selectedDateStr);
    attendanceMap = {
      for (final a in records) a.labourId: a.status.firestoreValue,
    };
    overtimeMap = {
      for (final a in records)
        if (a.overtimeHours > 0) a.labourId: a.overtimeHours,
    };
    notifyListeners();
  }

  Future<void> _fetchFromFirebase() async {
    isLoading = true;
    notifyListeners();
    await _service.fetchAttendanceForDate(selectedDateStr);
    _loadLocalAttendance();
    isLoading = false;
    notifyListeners();
  }

  Future<void> changeDate(DateTime newDate) async {
    selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
    _loadLocalAttendance();
    await _fetchFromFirebase();
  }

  Future<void> markAttendance(String labourId, String status) async {
    final existingOt = overtimeMap[labourId] ?? 0.0;
    final ot = status == 'absent' ? 0.0 : existingOt;

    final att = Attendance(
      id: '${labourId}_$selectedDateStr',
      labourId: labourId,
      supervisorId: FirebaseAuth.instance.currentUser!.uid,
      date: selectedDateStr,
      status: AttendanceStatusX.fromFirestoreValue(status),
      overtimeHours: ot,
    );
    await _service.markAttendance(att);
    attendanceMap[labourId] = status;
    if (ot > 0) {
      overtimeMap[labourId] = ot;
    } else {
      overtimeMap.remove(labourId);
    }
    notifyListeners();
  }

  Future<void> setOvertime(String labourId, double hours) async {
    final safe = hours.isFinite && hours > 0 ? hours : 0.0;
    final status = attendanceMap[labourId] ?? 'present';

    final att = Attendance(
      id: '${labourId}_$selectedDateStr',
      labourId: labourId,
      supervisorId: FirebaseAuth.instance.currentUser!.uid,
      date: selectedDateStr,
      status: AttendanceStatusX.fromFirestoreValue(status),
      overtimeHours: safe,
    );
    await _service.markAttendance(att);
    attendanceMap[labourId] = status;
    if (safe > 0) {
      overtimeMap[labourId] = safe;
    } else {
      overtimeMap.remove(labourId);
    }
    notifyListeners();
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
}
