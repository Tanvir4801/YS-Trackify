import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/attendance_model.dart';
import '../models/labour_model.dart';
import '../services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({AttendanceService? service})
      : _service = service ?? AttendanceService(),
        _labourBox = Hive.box<Labour>(Labour.boxName);

  final AttendanceService _service;
  final Box<Labour> _labourBox;

  DateTime selectedDate = DateTime.now();
  List<Labour> labours = <Labour>[];
  Map<String, String> attendanceMap = <String, String>{};
  bool isLoading = false;

  String get selectedDateStr => Attendance.formatDate(selectedDate);

  Future<void> initialize() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    labours = _labourBox.values
        .where((l) => l.isActive && (uid == null || l.supervisorId == uid))
        .toList();
    _loadLocalAttendance();
    await _fetchFromFirebase();
  }

  void _loadLocalAttendance() {
    final records = _service.getAttendanceForDate(selectedDateStr);
    attendanceMap = {
      for (final a in records) a.labourId: a.status.firestoreValue,
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
    final att = Attendance(
      id: '${labourId}_$selectedDateStr',
      labourId: labourId,
      supervisorId: FirebaseAuth.instance.currentUser!.uid,
      date: selectedDateStr,
      status: AttendanceStatusX.fromFirestoreValue(status),
      overtimeHours: 0,
    );
    await _service.markAttendance(att);
    attendanceMap[labourId] = status;
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
