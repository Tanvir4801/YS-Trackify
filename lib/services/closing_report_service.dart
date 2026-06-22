import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/daily_closing_report.dart';
import 'firestore_paths.dart';
import 'session_service.dart';

class ClosingReportService {
  ClosingReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // ── Generate Report ────────────────────────────────────────────────────────

  Future<DailyClosingReport> generateReport({
    required String contractorId,
    required String siteId,
    required String siteName,
    required String date,
    bool isRainHoliday = false,
  }) async {
    debugPrint('[ClosingReportService] Generating report for site=$siteId date=$date');

    // 1. Fetch attendance records for this date from nested path
    final recordsSnap = await FirestorePaths.attendanceRecordsCol(contractorId, date).get();

    // Also fetch flat attendance as fallback
    final uid = _auth.currentUser?.uid ?? '';
    final flatSnap = await _db
        .collection('attendance')
        .where('supervisorId', isEqualTo: uid)
        .get();

    // Merge records, filter by siteId and date
    final allRecords = <String, Map<String, dynamic>>{};

    // Nested records (preferred)
    for (final doc in recordsSnap.docs) {
      final data = doc.data();
      final recSiteId = (data['siteId'] as String?) ?? '';
      if (recSiteId == siteId || siteId.isEmpty) {
        final labourId = (data['labourId'] as String?) ?? doc.id;
        allRecords[labourId] = data;
      }
    }

    // Flat records (fallback for legacy data)
    for (final doc in flatSnap.docs) {
      final data = doc.data();
      final recDate = _extractDateString(data['date']);
      final recSiteId = (data['siteId'] as String?) ?? '';
      if (recDate == date && (recSiteId == siteId || siteId.isEmpty)) {
        final labourId = (data['labourId'] as String?) ?? doc.id;
        if (!allRecords.containsKey(labourId)) {
          allRecords[labourId] = data;
        }
      }
    }

    // 2. Compute attendance counts
    int present = 0, absent = 0, halfDay = 0;
    double totalWages = 0, totalAllowances = 0, totalAdvance = 0;

    for (final data in allRecords.values) {
      final status = (data['status'] as String?) ?? '';
      final wage = (data['wageAtTime'] as num?)?.toDouble() ?? 0;
      final allowanceMap = (data['allowances'] as Map<String, dynamic>?) ?? {};
      final petrol = (allowanceMap['petrol'] as num?)?.toDouble() ?? (data['petrol'] as num?)?.toDouble() ?? 0;
      final lunch = (allowanceMap['lunch'] as num?)?.toDouble() ?? (data['lunch'] as num?)?.toDouble() ?? 0;
      final breakfast = (allowanceMap['breakfast'] as num?)?.toDouble() ?? (data['breakfast'] as num?)?.toDouble() ?? 0;
      final tea = (allowanceMap['tea'] as num?)?.toDouble() ?? (data['tea'] as num?)?.toDouble() ?? 0;
      final advance = (data['advance'] as num?)?.toDouble() ?? 0;

      switch (status) {
        case 'present':
          present++;
          totalWages += wage;
          break;
        case 'absent':
          absent++;
          break;
        case 'half':
          halfDay++;
          totalWages += wage * 0.5;
          break;
      }

      totalAllowances += petrol + lunch + breakfast + tea;
      totalAdvance += advance;
    }

    final totalExpense = totalWages + totalAllowances;

    // 3. Fetch labour counts
    final laboursSnap = await _db
        .collection('labours')
        .where('contractorId', isEqualTo: contractorId)
        .where('isActive', isEqualTo: true)
        .get();

    final totalLabourCount = laboursSnap.docs.length;

    // Count new labours (joining date == today)
    int newLabourCount = 0;
    for (final doc in laboursSnap.docs) {
      final data = doc.data();
      final joiningDate = _extractDateString(data['joiningDate']);
      if (joiningDate == date) {
        newLabourCount++;
      }
    }

    // 4. Get supervisor name
    final supervisorName = SessionService.instance.name ?? 'Supervisor';

    // 5. Build report
    final report = DailyClosingReport(
      id: const Uuid().v4(),
      contractorId: contractorId,
      siteId: siteId,
      siteName: siteName,
      date: date,
      presentCount: present,
      absentCount: absent,
      halfDayCount: halfDay,
      totalLabourCost: totalWages,
      totalAdvance: totalAdvance,
      totalAllowances: totalAllowances,
      totalExpense: totalExpense,
      totalLabourCount: totalLabourCount,
      newLabourCount: newLabourCount,
      supervisorName: supervisorName,
      generatedAt: DateTime.now().toIso8601String(),
      isRainHoliday: isRainHoliday,
    );

    // 6. Generate insights by comparing with yesterday
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.parse(date).subtract(const Duration(days: 1)));
    final yesterdayReport = await _fetchReportForDate(contractorId, siteId, yesterday);
    final insights = generateInsights(report, yesterdayReport);

    return report.copyWith(insights: insights);
  }

  // ── Smart Insights ─────────────────────────────────────────────────────────

  List<String> generateInsights(
    DailyClosingReport today,
    DailyClosingReport? yesterday,
  ) {
    final insights = <String>[];

    if (today.isRainHoliday) {
      insights.add('\u{1F327}\u{FE0F} Site work was affected due to rain.');
    }

    if (yesterday != null) {
      if (today.presentCount > yesterday.presentCount) {
        insights.add('\u{1F4C8} Attendance improved compared to yesterday.');
      } else if (today.presentCount < yesterday.presentCount && yesterday.presentCount > 0) {
        insights.add('\u{1F4C9} Attendance declined compared to yesterday.');
      }

      if (today.totalExpense < yesterday.totalExpense && yesterday.totalExpense > 0) {
        insights.add('\u{1F4B0} Expenses reduced compared to yesterday.');
      } else if (today.totalExpense > yesterday.totalExpense * 1.2 && yesterday.totalExpense > 0) {
        insights.add('\u{1F4B8} Expenses increased significantly compared to yesterday.');
      }
    }

    if (today.totalLabourCount > 0 &&
        today.absentCount > (today.totalLabourCount * 0.2)) {
      insights.add('\u{26A0}\u{FE0F} High absenteeism detected today.');
    }

    if (today.newLabourCount > 0) {
      insights.add('\u{1F477} ${today.newLabourCount} new labourer(s) added today.');
    }

    if (today.totalLabourCost > 0 &&
        today.totalAdvance > (today.totalLabourCost * 0.3)) {
      insights.add('\u{1F4B8} High advance payments given today.');
    }

    if (today.totalLabourCount > 0 &&
        today.halfDayCount > (today.totalLabourCount * 0.15)) {
      insights.add('\u{1F550} Notable number of half-day workers today.');
    }

    if (insights.isEmpty) {
      insights.add('\u{2705} Site operations are running smoothly.');
    }

    return insights;
  }

  // ── Save Report ────────────────────────────────────────────────────────────

  Future<void> saveReport(DailyClosingReport report) async {
    final box = Hive.box<DailyClosingReport>(DailyClosingReport.boxName);
    await box.put(report.id, report);

    try {
      final docRef = FirestorePaths.closingReportDoc(
        report.contractorId,
        report.id,
      );
      await docRef.set(report.toFirestore());
      report.isSynced = true;
      report.firestoreId = docRef.id;
      await box.put(report.id, report);
      debugPrint('[ClosingReportService] Report saved & synced: ${report.id}');
    } catch (e) {
      debugPrint('[ClosingReportService] Firestore sync failed: $e');
    }
  }

  // ── Fetch Saved Reports ────────────────────────────────────────────────────

  Future<List<DailyClosingReport>> fetchSavedReports({
    required String contractorId,
    String? siteId,
    String? startDate,
    String? endDate,
  }) async {
    final box = Hive.box<DailyClosingReport>(DailyClosingReport.boxName);
    var reports = box.values
        .where((r) => r.contractorId == contractorId)
        .toList();

    if (siteId != null && siteId.isNotEmpty) {
      reports = reports.where((r) => r.siteId == siteId).toList();
    }

    if (startDate != null && startDate.isNotEmpty) {
      reports = reports.where((r) => r.date.compareTo(startDate) >= 0).toList();
    }

    if (endDate != null && endDate.isNotEmpty) {
      reports = reports.where((r) => r.date.compareTo(endDate) <= 0).toList();
    }

    try {
      Query<Map<String, dynamic>> query = FirestorePaths.closingReportsCol(contractorId);

      if (siteId != null && siteId.isNotEmpty) {
        query = query.where('siteId', isEqualTo: siteId);
      }

      final snap = await query.orderBy('date', descending: true).limit(50).get();

      for (final doc in snap.docs) {
        final firestoreReport = DailyClosingReport.fromFirestore(doc);
        if (!reports.any((r) => r.id == firestoreReport.id)) {
          reports.add(firestoreReport);
          await box.put(firestoreReport.id, firestoreReport);
        }
      }
    } catch (e) {
      debugPrint('[ClosingReportService] Firestore fetch failed: $e');
    }

    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports;
  }

  // ── WhatsApp Message Formatter ─────────────────────────────────────────────

  String formatWhatsAppMessage(DailyClosingReport report) {
    final dateStr = _formatDisplayDate(report.date);
    final currency = NumberFormat('#,##0', 'en_IN');

    final sb = StringBuffer();
    sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');
    sb.writeln('\u{1F3D7} DAILY SITE REPORT');
    sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');
    sb.writeln();
    sb.writeln('\u{1F4CD} Site');
    sb.writeln(report.siteName);
    sb.writeln();
    sb.writeln('\u{1F4C5} Date');
    sb.writeln(dateStr);
    sb.writeln();
    sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');
    sb.writeln('\u{1F477} ATTENDANCE');
    sb.writeln();
    sb.writeln('\u{2705} Present  : ${report.presentCount}');
    sb.writeln('\u{274C} Absent   : ${report.absentCount}');
    sb.writeln('\u{1F550} Half Day : ${report.halfDayCount}');
    sb.writeln();
    sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');
    sb.writeln('\u{1F4B0} EXPENSE SUMMARY');
    sb.writeln();
    sb.writeln('Labour Cost  : \u{20B9}${currency.format(report.totalLabourCost)}');
    sb.writeln('Advance Given : \u{20B9}${currency.format(report.totalAdvance)}');
    sb.writeln('Allowances   : \u{20B9}${currency.format(report.totalAllowances)}');
    sb.writeln();
    sb.writeln('Total Expense : \u{20B9}${currency.format(report.totalExpense)}');
    sb.writeln();
    sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');
    sb.writeln('\u{1F4CA} LABOUR DETAILS');
    sb.writeln();
    sb.writeln('Total Labour : ${report.totalLabourCount}');
    sb.writeln('New Labour   : ${report.newLabourCount}');
    sb.writeln();
    sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');
    sb.writeln('\u{1F4CC} SITE INSIGHTS');
    sb.writeln();
    for (final insight in report.insights) {
      sb.writeln('\u{2022} $insight');
    }
    sb.writeln();

    if (report.supervisorRemarks.isNotEmpty) {
      sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');
      sb.writeln('\u{1F4DD} SUPERVISOR NOTES');
      sb.writeln();
      for (final line in report.supervisorRemarks.split('\n')) {
        if (line.trim().isNotEmpty) {
          sb.writeln('\u{2022} ${line.trim()}');
        }
      }
      sb.writeln();
    }

    sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');
    sb.writeln('Generated by Trackify');
    sb.writeln('\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}\u{2501}');

    return sb.toString();
  }

  // ── Share & Copy ───────────────────────────────────────────────────────────

  Future<void> shareOnWhatsApp(DailyClosingReport report) async {
    final message = formatWhatsAppMessage(report);
    await Share.share(message, subject: 'Daily Site Report - ${report.siteName}');
  }

  Future<void> copyToClipboard(DailyClosingReport report) async {
    final message = formatWhatsAppMessage(report);
    await Clipboard.setData(ClipboardData(text: message));
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  Future<DailyClosingReport?> _fetchReportForDate(
    String contractorId,
    String siteId,
    String date,
  ) async {
    final box = Hive.box<DailyClosingReport>(DailyClosingReport.boxName);
    final local = box.values.where(
      (r) => r.contractorId == contractorId && r.siteId == siteId && r.date == date,
    );
    if (local.isNotEmpty) return local.first;

    try {
      final snap = await FirestorePaths.closingReportsCol(contractorId)
          .where('siteId', isEqualTo: siteId)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return DailyClosingReport.fromFirestore(snap.docs.first);
      }
    } catch (e) {
      debugPrint('[ClosingReportService] fetchReportForDate error: $e');
    }
    return null;
  }

  String _extractDateString(dynamic value) {
    if (value is String && value.isNotEmpty) return value.split('T').first;
    if (value is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(value.toDate());
    }
    if (value is DateTime) {
      return DateFormat('yyyy-MM-dd').format(value);
    }
    return '';
  }

  String _formatDisplayDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('d MMMM yyyy').format(dt);
    } catch (_) {
      return date;
    }
  }
}
