import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/session_service.dart';

class ReportsProvider extends ChangeNotifier {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int    month = DateTime.now().month;
  int    year  = DateTime.now().year;

  List<LabourMonthlyReport> reports = [];
  ReportSummary?            summary;
  bool    isLoading = false;
  String? error;

  Timer? _debounce;
  final List<StreamSubscription> _subs = [];
  String get uid => _auth.currentUser?.uid ?? '';

  void _scheduleBuild(String monthStr) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final snap = await _db.collection('labours')
          .where('supervisorId', isEqualTo: uid)
          .get();
      await _buildReports(snap.docs, monthStr);
    });
  }

  void loadReport({int? month, int? year}) {
    if (month != null) this.month = month;
    if (year  != null) this.year  = year;
    _cancelSubs();
    _startReportStreams();
  }

  void _startReportStreams() {
    isLoading = true;
    notifyListeners();

    final monthStr = '$year-${month.toString().padLeft(2,'0')}';

    // Stream 1: all labours for this supervisor
    final labourSub = _db.collection('labours')
        .where('supervisorId', isEqualTo: uid)
        .snapshots()
        .listen((_) => _scheduleBuild(monthStr));
    _subs.add(labourSub);

    // Stream 2: attendance changes this month → rebuild
    final nextMonthStr = month == 12 ? '${year+1}-01' : '$year-${(month+1).toString().padLeft(2, '0')}';
    final attSub = _db.collection('attendance')
        .where('supervisorId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
        .where('date', isLessThan: '$nextMonthStr-01')
        .snapshots()
        .listen((_) => _scheduleBuild(monthStr));
    _subs.add(attSub);

    // Stream 3: payments changes → rebuild
    final startTs = Timestamp.fromDate(DateTime(year, month, 1));
    final endTs   = Timestamp.fromDate(DateTime(year, month + 1, 0, 23, 59, 59));
    final paySub = _db.collection('payments')
        .where('supervisorId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: startTs)
        .where('date', isLessThanOrEqualTo: endTs)
        .snapshots()
        .listen((_) => _scheduleBuild(monthStr));
    _subs.add(paySub);
  }

  Future<void> _buildReports(
    List<QueryDocumentSnapshot> labourDocs,
    String monthStr,
  ) async {
    try {
      final results = <LabourMonthlyReport>[];
      
      // Batch fetch legacy root attendance
      final nextMonthStr = month == 12 ? '${year+1}-01' : '$year-${(month+1).toString().padLeft(2, '0')}';
      final allAttSnap = await _db.collection('attendance')
          .where('supervisorId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
          .where('date', isLessThan: '$nextMonthStr-01')
          .get();
          
      final fetchedRecords = <Map<String, dynamic>>[];
      for (final doc in allAttSnap.docs) {
        fetchedRecords.add(doc.data());
      }
      
      // Batch fetch multi-site nested attendance
      final cId = SessionService.instance.contractorId ?? uid;
      if (cId.isNotEmpty) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        for (var day = 1; day <= daysInMonth; day++) {
          final dateKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          try {
            final nestedSnap = await _db
                .collection('attendance')
                .doc(cId)
                .collection('dates')
                .doc(dateKey)
                .collection('records')
                .get();
            for (final doc in nestedSnap.docs) {
              final data = doc.data();
              if (data['supervisorId'] == uid || data['contractorId'] == uid) {
                fetchedRecords.add(data);
              }
            }
          } catch (_) {}
        }
      }

      // Batch fetch all sites to resolve names
      final sitesSnap = await _db.collection('sites')
          .where('contractorId', isEqualTo: cId)
          .get();
          
      // Also fetch sites where contractorId is the supervisor's uid (for older sites)
      final sitesSnapSup = cId != uid 
          ? await _db.collection('sites').where('contractorId', isEqualTo: uid).get()
          : null;
          
      final siteNames = <String, String>{};
      final allSiteDocs = [
        ...sitesSnap.docs, 
        if (sitesSnapSup != null) ...sitesSnapSup.docs
      ];
      
      for (var doc in allSiteDocs) {
        final d = doc.data();
        siteNames[doc.id] = d['name'] as String? ?? doc.id;
        if (d['id'] != null) {
          siteNames[d['id']] = d['name'] as String? ?? d['id'];
        }
      }
          
      // Batch fetch all payments
      final startTs = Timestamp.fromDate(DateTime(year, month, 1));
      final endTs   = Timestamp.fromDate(DateTime(year, month + 1, 0, 23, 59, 59));
      
      final allPaySnap = await _db.collection('payments')
          .where('supervisorId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: startTs)
          .where('date', isLessThanOrEqualTo: endTs)
          .get();

      // Group data by labourId in memory
      final attByLabour = <String, List<Map<String, dynamic>>>{};
      for (var d in fetchedRecords) {
        final lId = d['labourId'] as String?;
        if (lId != null) {
          attByLabour.putIfAbsent(lId, () => []).add(d);
        }
      }

      final payByLabour = <String, List<Map<String, dynamic>>>{};
      for (var doc in allPaySnap.docs) {
        final d = doc.data();
        final lId = d['labourId'] as String?;
        if (lId != null) {
          payByLabour.putIfAbsent(lId, () => []).add(d);
        }
      }

      for (final labourDoc in labourDocs) {
        final labData  = labourDoc.data() as Map<String, dynamic>;
        final labourId = labourDoc.id;

        // Group by date to get daily totals
        final byDate = <String, List<Map<String, dynamic>>>{};
        final labourAtt = attByLabour[labourId] ?? [];
        for (var d in labourAtt) {
          final date = d['date'] as String? ?? '';
          if (date.startsWith(monthStr)) {
            byDate.putIfAbsent(date, () => []).add(d);
          }
        }

        // Calculate days and wages date by date
        double totalShiftDays  = 0;
        double totalWage       = 0;
        double totalOTPay      = 0;
        int    daysWithRecords = 0;
        final siteBreakdown    = <String, SiteReport>{};

        byDate.forEach((date, records) {
          double dayFactor = 0;
          double dayWage   = 0;

          for (final rec in records) {
            final factor = (rec['shiftFactor'] as num?)?.toDouble()
                ?? _statusToFactor(rec['status'] as String? ?? '');
            final wage = (rec['dailyWageSnapshot'] as num?)?.toDouble()
                ?? (rec['wageAtTime'] as num?)?.toDouble()
                ?? (labData['dailyWage'] as num?)?.toDouble() ?? 0;
            final ot     = (rec['overtimeHours'] as num?)?.toDouble() ?? 0;
            final otRate = (rec['otRateSnapshot'] as num?)?.toDouble()
                ?? (labData['overtimeWagePerHour'] as num?)?.toDouble() ?? 0;
            final siteId   = rec['siteId']   as String? ?? 'no_site';
            final rawName = rec['siteName'] as String?;
            final siteName = siteNames[siteId] ?? rawName ?? siteId;

            dayFactor += factor;
            dayWage   += factor * wage;
            totalOTPay += ot * otRate;

            // Track per-site breakdown
            siteBreakdown.putIfAbsent(siteId, () =>
              SiteReport(siteId: siteId, siteName: siteName));
            siteBreakdown[siteId]!.addRecord(factor: factor, wage: wage * factor);
          }

          totalShiftDays  += dayFactor.clamp(0.0, 1.0);
          totalWage       += dayWage;
          if (dayFactor > 0) daysWithRecords++;
        });

        // TEMP LABOUR: include but mark separately
        final isTemp  = labData['type'] == 'temporary';
        final dailyWage = (labData['dailyWage'] as num?)?.toDouble() ?? 0;

        // Advances this month
        final labourPay = payByLabour[labourId] ?? [];
        final totalAdvances = labourPay
            .where((d) {
               if (d['type'] != 'advance') return false;
               final dateTs = d['date'] as Timestamp?;
               if (dateTs == null) return false;
               return dateTs.compareTo(startTs) >= 0 && dateTs.compareTo(endTs) <= 0;
            })
            .fold(0.0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));

        final grossSalary = totalWage + totalOTPay;
        final netPayable  = grossSalary - totalAdvances;

        final isActive = labData['isActive'] == true;
        if (!isActive && totalShiftDays == 0 && totalAdvances == 0) {
          continue; // Skip inactive workers with no data this month
        }

      results.add(LabourMonthlyReport(
        labourId:      labourId,
        labourName:    labData['name']  as String? ?? '',
        phone:         labData['phone'] as String? ?? '',
        dailyWage:     dailyWage,
        isTemp:        isTemp,
        totalDays:     totalShiftDays,
        totalWage:     totalWage,
        totalOTPay:    totalOTPay,
        grossSalary:   grossSalary,
        totalAdvances: totalAdvances,
        netPayable:    netPayable,
        siteBreakdown: siteBreakdown.values.toList(),
        attendanceByDate: byDate,
      ));
    }

    // Sort: regular labours first, then temp
    results.sort((a, b) {
      if (a.isTemp != b.isTemp) return a.isTemp ? 1 : -1;
      return a.labourName.compareTo(b.labourName);
    });

    reports = results;
    summary = ReportSummary(
      month:           month,
      year:            year,
      totalLabours:    results.where((r) => !r.isTemp).length,
      tempLabours:     results.where((r) =>  r.isTemp).length,
      totalGross:      results.fold(0, (s, r) => s + r.grossSalary),
      totalAdvances:   results.fold(0, (s, r) => s + r.totalAdvances),
      totalNet:        results.fold(0, (s, r) => s + r.netPayable),
      totalDaysWorked: results.fold(0.0, (s, r) => s + r.totalDays),
    );

    isLoading = false;
    error     = null;
    notifyListeners();

    debugPrint('Reports built: ${results.length} labours, '
        'gross=₹${summary!.totalGross}');
    } catch (e, stack) {
      debugPrint('Error building reports: $e');
      debugPrint(stack.toString());
      error = 'Failed to load reports';
      isLoading = false;
      notifyListeners();
    }
  }

  double _statusToFactor(String s) {
    if (s == 'present') return 1.0;
    if (s == 'half')    return 0.5;
    return 0.0;
  }

  void previousMonth() {
    if (month == 1) { month = 12; year--; }
    else {
      month--;
    }
    loadReport();
  }

  void nextMonth() {
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      if (month == 12) { month = 1; year++; }
      else {
        month++;
      }
      loadReport();
    }
  }

  void _cancelSubs() {
    for (var s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() { 
    _debounce?.cancel();
    _cancelSubs(); 
    super.dispose(); 
  }
}

// ── Data models ──────────────────────────────────────────────

class LabourMonthlyReport {
  const LabourMonthlyReport({
    required this.labourId,
    required this.labourName,
    required this.phone,
    required this.dailyWage,
    required this.isTemp,
    required this.totalDays,
    required this.totalWage,
    required this.totalOTPay,
    required this.grossSalary,
    required this.totalAdvances,
    required this.netPayable,
    required this.siteBreakdown,
    required this.attendanceByDate,
  });

  final String labourId, labourName, phone;
  final double dailyWage;
  final bool   isTemp;
  final double totalDays, totalWage, totalOTPay;
  final double grossSalary, totalAdvances, netPayable;
  final List<SiteReport>                      siteBreakdown;
  final Map<String, List<Map<String, dynamic>>> attendanceByDate;
}

class SiteReport {
  SiteReport({required this.siteId, required this.siteName});
  final String siteId, siteName;
  double totalFactor = 0;
  double totalWage   = 0;
  int    daysCount   = 0;

  void addRecord({required double factor, required double wage}) {
    totalFactor += factor;
    totalWage   += wage;
    if (factor > 0) daysCount++;
  }
}

class ReportSummary {
  const ReportSummary({
    required this.month,
    required this.year,
    required this.totalLabours,
    required this.tempLabours,
    required this.totalGross,
    required this.totalAdvances,
    required this.totalNet,
    required this.totalDaysWorked,
  });
  final int    month, year, totalLabours, tempLabours;
  final double totalGross, totalAdvances, totalNet, totalDaysWorked;
  String get monthName {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[month]} $year';
  }
}
