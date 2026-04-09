import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/utils/date_utils.dart';
import '../models/attendance_record.dart';
import '../models/labour.dart';
import '../models/labour_report_summary.dart';
import '../services/hive_service.dart';
import '../services/labour_mode/payment_service.dart';

class SiteDataProvider extends ChangeNotifier {
  SiteDataProvider({required HiveService hiveService})
      : _hiveService = hiveService;

  final HiveService _hiveService;
  PaymentService get _paymentService => PaymentService(hiveService: _hiveService);
  HiveService get hiveService => _hiveService;
  final Random _random = Random();

  List<Labour> _labours = [];
  List<AttendanceRecord> _attendanceRecords = [];
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;
  List<Labour> get labours => List.unmodifiable(_labours);

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
    _labours = _hiveService.getAllLabours();
    _attendanceRecords = _hiveService.getAllAttendanceRecords();
    await _backfillAdvancePayments();
    _setLoading(false);
  }

  void setSelectedDate(DateTime value) {
    _selectedDate = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  Future<void> addLabour({
    required String name,
    required String role,
    required double dailyWage,
    required String phoneNumber,
    double advanceAmount = 0,
    double extraHours = 0,
    double overtimeRate = 0,
  }) async {
    final labour = Labour(
      id: _id(),
      name: name,
      role: role,
      dailyWage: dailyWage,
      phoneNumber: phoneNumber,
      advanceAmount: advanceAmount,
      extraHours: extraHours,
      overtimeRate: overtimeRate,
    );

    await _hiveService.addLabour(labour);
    _labours = _hiveService.getAllLabours();
    notifyListeners();
  }

  Future<void> updateLabour(Labour labour) async {
    await _hiveService.updateLabour(labour);
    _labours = _hiveService.getAllLabours();
    notifyListeners();
  }

  /// Add advance payment (accumulates to existing advance)
  /// Formula: advance += newAmount
  Future<void> addAdvancePayment({
    required String labourId,
    required double amount,
  }) async {
    if (amount <= 0) {
      return;
    }

    final index = _labours.indexWhere((item) => item.id == labourId);
    if (index == -1) {
      return;
    }

    final labour = _labours[index];
    final newAdvanceAmount = labour.advanceAmount + amount;

    await updateLabour(
      labour.copyWith(advanceAmount: newAdvanceAmount),
    );

    await _paymentService.recordPayment(
      labourId: labourId,
      amount: amount,
      date: AppDateUtils.toDateKey(DateTime.now()),
    );
  }

  Future<void> _backfillAdvancePayments() async {
    for (final labour in _labours) {
      if (labour.advanceAmount <= 0) {
        continue;
      }

      final existingPayments = _hiveService.getPaymentsForLabour(labour.id);
      if (existingPayments.isNotEmpty) {
        continue;
      }

      await _paymentService.recordPayment(
        labourId: labour.id,
        amount: labour.advanceAmount,
        date: AppDateUtils.toDateKey(DateTime.now()),
      );
    }
  }

  /// Add overtime hours (accumulates to existing hours)
  /// Formula: extraHours += newHours
  /// Updates the overtime rate for calculations
  Future<void> addOvertimeRecord({
    required String labourId,
    required double hours,
    required double rate,
  }) async {
    if (hours <= 0 || rate <= 0) {
      return;
    }

    final index = _labours.indexWhere((item) => item.id == labourId);
    if (index == -1) {
      return;
    }

    final labour = _labours[index];
    final newExtraHours = labour.extraHours + hours;

    await updateLabour(
      labour.copyWith(
        extraHours: newExtraHours,
        overtimeRate: rate, // Update rate for next calculation
      ),
    );
  }

  Future<void> deleteLabour(String labourId) async {
    await _hiveService.deleteLabour(labourId);
    _labours = _hiveService.getAllLabours();
    _attendanceRecords = _hiveService.getAllAttendanceRecords();
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

  /// Total advance paid across all labourers
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
      final status = attendanceByLabour[labour.id]?.status;
      if (status == null) {
        continue;
      }
      total += labour.dailyWage * status.factor;
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

  /// Build labour report with calculations
  /// Formulas:
  /// - totalEarned = daysWorked × dailyWage
  /// - overtimePay = extraHours × overtimeRate
  /// - finalPay = totalEarned + overtimePay - advance
  List<LabourReportSummary> buildLabourReport() {
    final result = <LabourReportSummary>[];

    for (final labour in _labours) {
      final records =
          _attendanceRecords.where((record) => record.labourId == labour.id);
      var present = 0;
      var absent = 0;
      var half = 0;
      var wage = 0.0;

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
      }

      result.add(
        LabourReportSummary(
          labourName: labour.name,
          role: labour.role,
          presentDays: present,
          halfDays: half,
          absentDays: absent,
          totalEarned: wage,
          overtimePay: labour.overtimePay, // extraHours × overtimeRate
          advanceAmount: labour.advanceAmount,
          extraHours: labour.extraHours,
        ),
      );
    }

    return result;
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
}
