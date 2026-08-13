import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'hive_service.dart';
import '../models/attendance_record.dart';
import '../models/payment.dart';

class OfflineCleanupService {
  static const int _retentionDays = 30;

  static Future<void> runCleanup() async {
    try {
      debugPrint('OfflineCleanup: starting stale data cleanup');
      final cutoffDate = DateTime.now().subtract(const Duration(days: _retentionDays));

      await _cleanupAttendance(cutoffDate);
      await _cleanupPayments(cutoffDate);

      debugPrint('OfflineCleanup: completed');
    } catch (e) {
      debugPrint('OfflineCleanup error: $e');
    }
  }

  static Future<void> _cleanupAttendance(DateTime cutoff) async {
    try {
      final box = Hive.box<AttendanceRecord>(HiveService.attendanceBoxName);
      final keysToDelete = <dynamic>[];

      for (final key in box.keys) {
        final record = box.get(key);
        if (record != null) {
          try {
            final dateParts = record.dateKey.split('-'); // YYYY-MM-DD
            if (dateParts.length == 3) {
              final recordDate = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
              );
              if (recordDate.isBefore(cutoff)) {
                keysToDelete.add(key);
              }
            }
          } catch (_) {
            // ignore malformed date
          }
        }
      }

      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        debugPrint('OfflineCleanup: deleted ${keysToDelete.length} attendance records');
      }
    } catch (e) {
      debugPrint('OfflineCleanup attendance error: $e');
    }
  }

  static Future<void> _cleanupPayments(DateTime cutoff) async {
    try {
      final box = Hive.box<Payment>(HiveService.paymentBoxName);
      final keysToDelete = <dynamic>[];

      for (final key in box.keys) {
        final payment = box.get(key);
        if (payment != null) {
          final pDate = DateTime.tryParse(payment.date);
          if (pDate != null && pDate.isBefore(cutoff)) {
            keysToDelete.add(key);
          }
        }
      }

      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        debugPrint('OfflineCleanup: deleted ${keysToDelete.length} payment records');
      }
    } catch (e) {
      debugPrint('OfflineCleanup payment error: $e');
    }
  }
}
