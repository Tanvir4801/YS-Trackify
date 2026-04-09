import 'package:hive_flutter/hive_flutter.dart';

import '../models/attendance_record.dart';
import '../models/labour.dart';
import '../models/payment.dart';

class HiveService {
  static const String labourBoxName = 'labour_box';
  static const String attendanceBoxName = 'attendance_box';
  static const String paymentBoxName = 'payment_box';

  Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LabourAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AttendanceStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AttendanceRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(PaymentAdapter());
    }

    await Hive.openBox<Labour>(labourBoxName);
    await Hive.openBox<AttendanceRecord>(attendanceBoxName);
    await Hive.openBox<Payment>(paymentBoxName);
  }

  Box<Labour> get _labourBox => Hive.box<Labour>(labourBoxName);
  Box<AttendanceRecord> get _attendanceBox =>
      Hive.box<AttendanceRecord>(attendanceBoxName);
  Box<Payment> get _paymentBox => Hive.box<Payment>(paymentBoxName);

  List<Labour> getAllLabours() => _labourBox.values.toList();

  Labour? getLabourById(String labourId) => _labourBox.get(labourId);

  Labour? getLabourByPhoneNumber(String phoneNumber) {
    final normalizedInput = _normalizePhone(phoneNumber);
    for (final labour in _labourBox.values) {
      if (_normalizePhone(labour.phoneNumber) == normalizedInput) {
        return labour;
      }
    }
    return null;
  }

  Future<void> addLabour(Labour labour) async {
    await _labourBox.put(labour.id, labour);
  }

  Future<void> updateLabour(Labour labour) async {
    await _labourBox.put(labour.id, labour);
  }

  Future<void> deleteLabour(String labourId) async {
    await _labourBox.delete(labourId);

    final keysToDelete = _attendanceBox.keys.where((key) {
      final record = _attendanceBox.get(key);
      return record?.labourId == labourId;
    }).toList();

    await _attendanceBox.deleteAll(keysToDelete);
  }

  List<AttendanceRecord> getAllAttendanceRecords() =>
      _attendanceBox.values.toList();

  List<AttendanceRecord> getAttendanceForDate(String dateKey) {
    return _attendanceBox.values
        .where((record) => record.dateKey == dateKey)
        .toList();
  }

  Future<void> upsertAttendance(AttendanceRecord record) async {
    final existingKey = _attendanceBox.keys.cast<dynamic>().firstWhere(
      (key) {
        final existing = _attendanceBox.get(key);
        return existing?.labourId == record.labourId &&
            existing?.dateKey == record.dateKey;
      },
      orElse: () => null,
    );

    if (existingKey != null) {
      await _attendanceBox.put(existingKey, record);
      return;
    }

    await _attendanceBox.put(record.id, record);
  }

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  // Payment methods
  List<Payment> getPaymentsForLabour(String labourId) {
    final payments = _paymentBox.values
        .where((payment) => payment.labourId == labourId)
        .toList();
    // Sort by date (latest first)
    payments.sort((a, b) => b.date.compareTo(a.date));
    return payments;
  }

  List<Payment> getAllPayments() => _paymentBox.values.toList();

  Future<void> addPayment(Payment payment) async {
    await _paymentBox.put(payment.id, payment);
  }

  Future<void> deletePayment(String paymentId) async {
    await _paymentBox.delete(paymentId);
  }
}
