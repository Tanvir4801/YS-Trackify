import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_closing_report.dart';
import '../services/closing_report_service.dart';
import '../services/notification_service.dart';
import '../services/report_export_service.dart';
import '../services/session_service.dart';

class ClosingReportProvider extends ChangeNotifier {
  ClosingReportProvider();

  final ClosingReportService _service = ClosingReportService();
  final ReportExportService _exportService = ReportExportService();

  DailyClosingReport? _currentReport;
  DailyClosingReport? get currentReport => _currentReport;

  List<DailyClosingReport> _savedReports = [];
  List<DailyClosingReport> get savedReports => _savedReports;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _error;
  String? get error => _error;

  bool _reminderEnabled = false;
  bool get reminderEnabled => _reminderEnabled;

  // ── Generate Report ────────────────────────────────────────────────────────

  Future<void> generateReport({
    required String siteId,
    required String siteName,
    required String date,
    bool isRainHoliday = false,
  }) async {
    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final contractorId = SessionService.instance.contractorId ?? uid;

      _currentReport = await _service.generateReport(
        contractorId: contractorId,
        siteId: siteId,
        siteName: siteName,
        date: date,
        isRainHoliday: isRainHoliday,
      );
    } catch (e) {
      _error = 'Failed to generate report: $e';
      debugPrint('[ClosingReportProvider] $error');
    }

    _isGenerating = false;
    notifyListeners();
  }

  // ── Supervisor Remarks ─────────────────────────────────────────────────────

  void setSupervisorRemarks(String remarks) {
    if (_currentReport != null) {
      _currentReport = _currentReport!.copyWith(supervisorRemarks: remarks);
      notifyListeners();
    }
  }

  void setRainHoliday(bool value) {
    if (_currentReport != null) {
      _currentReport = _currentReport!.copyWith(isRainHoliday: value);
      // Regenerate insights with updated rain flag
      final insights = _service.generateInsights(_currentReport!, null);
      _currentReport = _currentReport!.copyWith(insights: insights);
      notifyListeners();
    }
  }

  // ── Save Report ────────────────────────────────────────────────────────────

  Future<bool> saveReport() async {
    if (_currentReport == null) return false;

    _isSaving = true;
    notifyListeners();

    try {
      await _service.saveReport(_currentReport!);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to save report: $e';
      debugPrint('[ClosingReportProvider] $error');
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  // ── Share & Export ─────────────────────────────────────────────────────────

  Future<void> shareWhatsApp() async {
    if (_currentReport == null) return;
    await _service.shareOnWhatsApp(_currentReport!);
  }

  Future<void> downloadPdf() async {
    if (_currentReport == null) return;
    await _exportService.exportClosingReportPdf(_currentReport!);
  }

  Future<void> copyReport() async {
    if (_currentReport == null) return;
    await _service.copyToClipboard(_currentReport!);
  }

  // ── Share/Export for a specific saved report ───────────────────────────────

  Future<void> shareWhatsAppReport(DailyClosingReport report) async {
    await _service.shareOnWhatsApp(report);
  }

  Future<void> downloadPdfReport(DailyClosingReport report) async {
    await _exportService.exportClosingReportPdf(report);
  }

  // ── Load History ───────────────────────────────────────────────────────────

  Future<void> loadHistory({
    String? siteId,
    String? startDate,
    String? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final contractorId = SessionService.instance.contractorId ?? uid;

      _savedReports = await _service.fetchSavedReports(
        contractorId: contractorId,
        siteId: siteId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _error = 'Failed to load history: $e';
      debugPrint('[ClosingReportProvider] $error');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Reminder ───────────────────────────────────────────────────────────────

  Future<void> toggleReminder() async {
    _reminderEnabled = !_reminderEnabled;
    notifyListeners();

    if (_reminderEnabled) {
      await NotificationService.instance.scheduleDailyReportReminder();
    } else {
      await NotificationService.instance.cancelDailyReportReminder();
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  void clearCurrentReport() {
    _currentReport = null;
    _error = null;
    notifyListeners();
  }
}
