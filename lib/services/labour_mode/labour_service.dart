import '../../core/utils/date_utils.dart';
import '../../models/attendance_record.dart';
import '../../models/labour.dart';
import '../hive_service.dart';

class LabourDashboardSummary {
  LabourDashboardSummary({
    required this.totalDaysWorked,
    required this.dailyWage,
    required this.basePay,
    required this.extraHours,
    required this.overtimeRate,
    required this.overtimePay,
    required this.totalEarned,
    required this.advanceTaken,
    required this.finalPay,
  });

  final double totalDaysWorked;
  final double dailyWage;
  final double basePay;
  final double extraHours;
  final double overtimeRate;
  final double overtimePay;
  final double totalEarned;
  final double advanceTaken;
  final double finalPay;
}

class LabourService {
  LabourService({required HiveService hiveService})
      : _hiveService = hiveService;

  final HiveService _hiveService;

  List<Labour> getAllLabours() {
    final labours = _hiveService.getAllLabours();
    labours
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return labours;
  }

  List<AttendanceRecord> getAttendanceForLabour(String labourId) {
    final records = _hiveService
        .getAllAttendanceRecords()
        .where((record) => record.labourId == labourId)
        .toList();

    records.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return records;
  }

  LabourDashboardSummary buildDashboardSummary(Labour labour) {
    final records = getAttendanceForLabour(labour.id);

    var daysWorked = 0.0;
    for (final record in records) {
      daysWorked += record.status.factor;
    }

    // Formulas:
    final basePay = labour.dailyWage * daysWorked;
    final overtimePay = labour.extraHours * labour.overtimeRate;
    final totalEarned = basePay + overtimePay;
    final finalPay = totalEarned - labour.advanceAmount;

    return LabourDashboardSummary(
      totalDaysWorked: daysWorked,
      dailyWage: labour.dailyWage,
      basePay: basePay,
      extraHours: labour.extraHours,
      overtimeRate: labour.overtimeRate,
      overtimePay: overtimePay,
      totalEarned: totalEarned,
      advanceTaken: labour.advanceAmount,
      finalPay: finalPay,
    );
  }

  String formatDate(String dateKey) {
    try {
      final date = AppDateUtils.fromDateKey(dateKey);
      return AppDateUtils.toDisplay(date);
    } catch (_) {
      return dateKey;
    }
  }
}
