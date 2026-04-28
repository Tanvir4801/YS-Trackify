import 'package:share_plus/share_plus.dart';

import 'package:flutter/foundation.dart';

import '../models/labour_report_summary.dart';
import '../services/report_service.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider({ReportService? service}) : _service = service ?? ReportService();

  final ReportService _service;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> salaryReport = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> attendanceReport = <Map<String, dynamic>>[];
  bool isLoading = false;
  bool isExporting = false;
  bool isBackingUp = false;
  String? exportedFilePath;
  String? error;

  List<LabourReportSummary> get summaries {
    return salaryReport
        .map(
          (r) => LabourReportSummary(
            labourName: (r['labourName'] as String?) ?? '',
            role: (r['role'] as String?) ?? '-',
            presentDays: (r['daysPresent'] as int?) ?? 0,
            halfDays: (r['daysHalf'] as num?)?.toInt() ?? 0,
            absentDays: (r['daysAbsent'] as int?) ?? 0,
            totalEarned: (r['grossSalary'] as num?)?.toDouble() ?? 0,
            overtimePay: (r['overtimePay'] as num?)?.toDouble() ?? 0,
            advanceAmount: (r['totalAdvances'] as num?)?.toDouble() ?? 0,
            extraHours: (r['overtimeHours'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
  }

  double get totalGross =>
      salaryReport.fold<double>(0, (s, r) => s + ((r['grossSalary'] as num?)?.toDouble() ?? 0));

  double get totalAdvances =>
      salaryReport.fold<double>(0, (s, r) => s + ((r['totalAdvances'] as num?)?.toDouble() ?? 0));

  double get totalNet =>
      salaryReport.fold<double>(0, (s, r) => s + ((r['netPayable'] as num?)?.toDouble() ?? 0));

  Future<void> loadReport() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _service.fetchMonthData(selectedMonth, selectedYear);
      salaryReport = _service.generateSalaryReport(selectedMonth, selectedYear);
      attendanceReport = _service.generateAttendanceReport(selectedMonth, selectedYear);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void changeMonth(int month, int year) {
    selectedMonth = month;
    selectedYear = year;
    loadReport();
  }

  Future<void> exportExcel() async {
    isExporting = true;
    error = null;
    notifyListeners();
    try {
      exportedFilePath = await _service.exportToExcel(selectedMonth, selectedYear);
      await Share.shareXFiles(
        <XFile>[XFile(exportedFilePath!)],
        subject: 'Trackify Report $selectedMonth/$selectedYear',
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<void> backupData() async {
    isBackingUp = true;
    error = null;
    notifyListeners();
    try {
      await _service.backupAllData();
    } catch (e) {
      error = e.toString();
    } finally {
      isBackingUp = false;
      notifyListeners();
    }
  }
}
