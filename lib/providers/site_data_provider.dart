import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/date_utils.dart';
import '../models/attendance_record.dart';
import '../models/labour.dart';
import '../models/labour_report_summary.dart';
import '../services/hive_service.dart';
import '../services/labour_mode/payment_service.dart';
import '../services/session_service.dart';

class SiteDataProvider extends ChangeNotifier {
  SiteDataProvider({required HiveService hiveService})
      : _hiveService = hiveService;

  final HiveService _hiveService;
  PaymentService get _paymentService => PaymentService(hiveService: _hiveService);
  HiveService get hiveService => _hiveService;
  final Random _random = Random();

  // Stream-backed labour list
  StreamSubscription<QuerySnapshot>? _labourSubscription;
  List<Labour> _labours = [];
  List<Labour> get labours => _labours;

  List<AttendanceRecord> _attendanceRecords = [];
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;

  String get selectedDateKey => AppDateUtils.toDateKey(_selectedDate);

  List<AttendanceRecord> get selectedDateAttendance {
    return _attendanceRecords
        .where((record) => record.dateKey == selectedDateKey)
        .toList();
  }

  Map<String, AttendanceRecord> get selectedDateAttendanceMap {
    final map = <String, AttendanceRecord>{};
    for (final item in selectedDateAttendance) {
      map[item.labourId] = item;
    }
    return map;
  }

  Future<void> initialize() async {
    _setLoading(true);
    _attendanceRecords = _hiveService.getAllAttendanceRecords();
    await _backfillAdvancePayments();
    _setLoading(false);
  }

  // ─── Firestore labour stream ───────────────────────────────────────────────

  void startLabourStream() {
    _labourSubscription?.cancel();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('❌ startLabourStream: no uid');
      return;
    }

    final contractorId = SessionService.instance.contractorId ?? uid;
    debugPrint('🔴 Starting labour stream for contractorId: $contractorId');

    _labourSubscription = FirebaseFirestore.instance
        .collection('labours')
        .where('contractorId', isEqualTo: contractorId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
      (snap) {
        _labours = snap.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return Labour(
            id: doc.id,
            name: d['name'] ?? '',
            role: d['skill'] ?? d['role'] ?? '',
            dailyWage: (d['dailyWage'] ?? d['dailyRate'] ?? 0).toDouble(),
            phoneNumber: d['phone'] ?? d['phoneNumber'] ?? '',
            advanceAmount: (d['advanceAmount'] ?? 0).toDouble(),
            extraHours: (d['defaultOvertimeHours'] ?? 0).toDouble(),
            overtimeRate: (d['overtimeWagePerHour'] ?? 0).toDouble(),
          );
        }).toList();

        _labours.sort((a, b) => a.name.compareTo(b.name));

        debugPrint('🔴 Labour stream updated: ${_labours.length} labours');
        notifyListeners();
      },
      onError: (e) {
        debugPrint('❌ Labour stream error: $e');
      },
    );
  }

  void stopLabourStream() {
    _labourSubscription?.cancel();
    _labourSubscription = null;
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> addLabour({
    required String name,
    required String role,
    required double dailyWage,
    required String phoneNumber,
    double advanceAmount = 0,
    double extraHours = 0,
    double overtimeRate = 0,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;

    try {
      final docRef = await db.collection('labours').add({
        'name': name,
        'skill': role,
        'role': role,
        'dailyWage': dailyWage,
        'dailyRate': dailyWage,
        'phone': phoneNumber,
        'phoneNumber': phoneNumber,
        'advanceAmount': advanceAmount,
        'defaultOvertimeHours': extraHours,
        'overtimeWagePerHour': overtimeRate,
        'supervisorId': uid,
        'supervisorRef': db.doc('users/$uid'),
        'contractorId': contractorId,
        'isActive': true,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      });

      await docRef.update({'id': docRef.id});
      debugPrint('✅ Labour added: $name → ${docRef.id}');
    } catch (e) {
      debugPrint('❌ addLabour failed: $e');
      rethrow;
    }
  }

  Future<void> updateLabour(Labour labour) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;

    try {
      await db.collection('labours').doc(labour.id).set({
        'name': labour.name,
        'skill': labour.role,
        'role': labour.role,
        'dailyWage': labour.dailyWage,
        'dailyRate': labour.dailyWage,
        'phone': labour.phoneNumber,
        'phoneNumber': labour.phoneNumber,
        'advanceAmount': labour.advanceAmount,
        'defaultOvertimeHours': labour.extraHours,
        'overtimeWagePerHour': labour.overtimeRate,
        'supervisorId': uid,
        'supervisorRef': db.doc('users/$uid'),
        'contractorId': contractorId,
        'isActive': true,
        'isSynced': true,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Labour updated: ${labour.name}');
    } catch (e) {
      debugPrint('❌ updateLabour failed: $e');
      rethrow;
    }
  }

  Future<void> deleteLabour(String labourId) async {
    try {
      await FirebaseFirestore.instance
          .collection('labours')
          .doc(labourId)
          .update({
        'isActive': false,
        'syncedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Labour deleted: $labourId');
    } catch (e) {
      debugPrint('❌ deleteLabour failed: $e');
      rethrow;
    }
  }

  Future<void> addAdvancePayment({
    required String labourId,
    required double amount,
  }) async {
    if (amount <= 0) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final contractorId = SessionService.instance.contractorId ?? uid;
    final db = FirebaseFirestore.instance;

    try {
      await db.collection('labours').doc(labourId).update({
        'advanceAmount': FieldValue.increment(amount),
        'syncedAt': FieldValue.serverTimestamp(),
      });

      await db.collection('payments').add({
        'contractorId': contractorId,
        'labourId': labourId,
        'labourRef': db.doc('labours/$labourId'),
        'amount': amount,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'paid',
        'notes': 'Advance payment',
        'createdBy': db.doc('users/$uid'),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Advance added: Rs$amount for $labourId');
    } catch (e) {
      debugPrint('❌ addAdvancePayment failed: $e');
      rethrow;
    }
  }

  // ─── Attendance (local Hive) ───────────────────────────────────────────────

  void setSelectedDate(DateTime value) {
    _selectedDate = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  Future<void> markAttendance({
    required String labourId,
    required AttendanceStatus status,
  }) async {
    final record = AttendanceRecord(
      id: _id(),
      labourId: labourId,
      dateKey: selectedDateKey,
      status: status,
    );

    await _hiveService.upsertAttendance(record);
    _attendanceRecords = _hiveService.getAllAttendanceRecords();
    notifyListeners();
  }

  Future<void> addOvertimeRecord({
    required String labourId,
    required double hours,
    required double rate,
  }) async {
    if (hours <= 0 || rate <= 0) return;

    final index = _labours.indexWhere((item) => item.id == labourId);
    if (index == -1) return;

    final labour = _labours[index];
    final newExtraHours = labour.extraHours + hours;

    await updateLabour(
      labour.copyWith(
        extraHours: newExtraHours,
        overtimeRate: rate,
      ),
    );
  }

  // ─── Computed stats ────────────────────────────────────────────────────────

  int get totalLabourCount => _labours.length;

  int get todayPresentCount =>
      _countByStatus(DateTime.now(), AttendanceStatus.present);
  int get todayAbsentCount =>
      _countByStatus(DateTime.now(), AttendanceStatus.absent);
  int get todayHalfDayCount =>
      _countByStatus(DateTime.now(), AttendanceStatus.halfDay);

  double get todayWageTotal => wageTotalForDate(DateTime.now());
  double get weekWageTotal => wageTotalForWeek(DateTime.now());
  double get monthWageTotal => wageTotalForMonth(DateTime.now());

  double get totalAdvancePaid =>
      _labours.fold(0, (sum, item) => sum + item.advanceAmount);

  double wageTotalForDate(DateTime date) {
    final dateKey = AppDateUtils.toDateKey(date);
    final attendanceByLabour = {
      for (final item
          in _attendanceRecords.where((record) => record.dateKey == dateKey))
        item.labourId: item,
    };

    var total = 0.0;
    for (final labour in _labours) {
      final record = attendanceByLabour[labour.id];
      if (record == null) continue;
      total += labour.dailyWage * record.status.factor;
      if (record.overtimeHours > 0 && labour.overtimeRate > 0) {
        total += record.overtimeHours * labour.overtimeRate;
      }
    }

    return total;
  }

  double wageTotalForWeek(DateTime date) {
    final start = AppDateUtils.startOfWeek(date);
    var total = 0.0;
    for (var i = 0; i < 7; i++) {
      total += wageTotalForDate(start.add(Duration(days: i)));
    }
    return total;
  }

  double wageTotalForMonth(DateTime date) {
    var total = 0.0;
    final first = DateTime(date.year, date.month, 1);
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    final days = nextMonth.difference(first).inDays;
    for (var i = 0; i < days; i++) {
      total += wageTotalForDate(first.add(Duration(days: i)));
    }
    return total;
  }

  List<LabourReportSummary> buildLabourReport() {
    final result = <LabourReportSummary>[];

    for (final labour in _labours) {
      final records =
          _attendanceRecords.where((record) => record.labourId == labour.id);
      var present = 0;
      var absent = 0;
      var half = 0;
      var wage = 0.0;
      var perDayOtHours = 0.0;
      var perDayOtPay = 0.0;

      for (final record in records) {
        switch (record.status) {
          case AttendanceStatus.present:
            present += 1;
            wage += labour.dailyWage;
            break;
          case AttendanceStatus.absent:
            absent += 1;
            break;
          case AttendanceStatus.halfDay:
            half += 1;
            wage += labour.dailyWage * 0.5;
            break;
        }
        if (record.overtimeHours > 0) {
          perDayOtHours += record.overtimeHours;
          perDayOtPay += record.overtimeHours * labour.overtimeRate;
        }
      }

      final overtimePay =
          perDayOtPay > 0 ? perDayOtPay : labour.overtimePay;
      final extraHours =
          perDayOtHours > 0 ? perDayOtHours : labour.extraHours;

      result.add(
        LabourReportSummary(
          labourName: labour.name,
          role: labour.role,
          presentDays: present,
          halfDays: half,
          absentDays: absent,
          totalEarned: wage,
          overtimePay: overtimePay,
          advanceAmount: labour.advanceAmount,
          extraHours: extraHours,
        ),
      );
    }

    return result;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _backfillAdvancePayments() async {
    for (final labour in _labours) {
      if (labour.advanceAmount <= 0) continue;

      final existingPayments = _hiveService.getPaymentsForLabour(labour.id);
      if (existingPayments.isNotEmpty) continue;

      await _paymentService.recordPayment(
        labourId: labour.id,
        amount: labour.advanceAmount,
        date: AppDateUtils.toDateKey(DateTime.now()),
      );
    }
  }

  int _countByStatus(DateTime date, AttendanceStatus status) {
    final dateKey = AppDateUtils.toDateKey(date);
    return _attendanceRecords
        .where((record) => record.dateKey == dateKey && record.status == status)
        .length;
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(999)}';

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    stopLabourStream();
    super.dispose();
  }
}
