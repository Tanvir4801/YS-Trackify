import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/report_export_service.dart';

class LabourReportTab extends StatefulWidget {
  const LabourReportTab({
    super.key,
    required this.labourId,
    required this.contractorId,
  });

  final String labourId;
  final String contractorId;

  @override
  State<LabourReportTab> createState() => _LabourReportTabState();
}

class _LabourReportTabState extends State<LabourReportTab> {
  final _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _flatSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nestedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paymentSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _labourDocSub;

  final Map<String, Map<String, dynamic>> _flatDocs   = {};
  final Map<String, Map<String, dynamic>> _nestedDocs = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _paymentDocs = [];

  int _month = DateTime.now().month;
  int _year  = DateTime.now().year;

  // Computed state
  int    _daysPresent   = 0;
  int    _daysHalf      = 0;
  int    _daysAbsent    = 0;
  double _totalOTHours  = 0;
  double _dailyWage     = 0;
  double _otRate        = 0;
  double _grossSalary   = 0;
  double _totalAdvances = 0;
  double _netPayable    = 0;
  List<Map<String, dynamic>> _paymentHistory    = [];
  List<Map<String, dynamic>> _attendanceRecords = [];

  // Labour info for export
  String _labourName = '';

  bool _loading      = true;
  bool _exporting    = false;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _startStreams();
  }

  @override
  void dispose() {
    _flatSub?.cancel();
    _nestedSub?.cancel();
    _paymentSub?.cancel();
    _labourDocSub?.cancel();
    super.dispose();
  }

  void _startStreams() {
    _flatSub?.cancel();
    _nestedSub?.cancel();
    _paymentSub?.cancel();
    _labourDocSub?.cancel();

    _labourDocSub = _db
        .collection('labours')
        .doc(widget.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data() ?? {};
      _dailyWage  = (data['dailyWage']  as num?)?.toDouble()
                 ?? (data['dailyRate']   as num?)?.toDouble() ?? 0;
      _otRate     = (data['overtimeWagePerHour'] as num?)?.toDouble() ?? 0;
      _labourName = (data['name'] as String? ?? '').trim();
      _rebuild();
    }, onError: (e) => debugPrint('[ReportTab] labourDoc: $e'));

    _flatSub = _db
        .collection('attendance')
        .where('labourId', isEqualTo: widget.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      _flatDocs.clear();
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = (data['date'] as String?) ?? '';
        if (date.isNotEmpty) _flatDocs['flat_${doc.id}'] = data;
      }
      _rebuild();
    }, onError: (e) {
      debugPrint('[ReportTab] flat: $e');
      if (mounted) _rebuild();
    });

    _nestedSub = _db
        .collectionGroup('records')
        .where('labourId', isEqualTo: widget.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      _nestedDocs.clear();
      for (final doc in snap.docs) {
        final data    = doc.data();
        final date    = (data['date']     as String?) ?? '';
        final lId     = (data['labourId'] as String?) ?? '';
        if (date.isNotEmpty && lId.isNotEmpty) {
          _nestedDocs['nested_${lId}_$date'] = data;
        }
      }
      _rebuild();
    }, onError: (e) => debugPrint('[ReportTab] nested (non-critical): $e'));

    _paymentSub = _db
        .collection('payments')
        .where('labourId', isEqualTo: widget.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      _paymentDocs = snap.docs;
      _rebuild();
    }, onError: (e) {
      debugPrint('[ReportTab] payments: $e');
      if (mounted) _rebuild();
    });
  }

  void _rebuild() {
    final monthStr = '$_year-${_month.toString().padLeft(2, '0')}';
    final attendance = <String, Map<String, dynamic>>{};

    for (final entry in _flatDocs.entries) {
      final data = entry.value;
      final date = (data['date'] as String?) ?? '';
      if (_matchesMonth(date, monthStr)) {
        final lId = (data['labourId'] as String?) ?? '';
        attendance['${lId}_$date'] = data;
      }
    }
    for (final entry in _nestedDocs.entries) {
      final data = entry.value;
      final date = (data['date'] as String?) ?? '';
      if (_matchesMonth(date, monthStr)) {
        final lId = (data['labourId'] as String?) ?? '';
        attendance['${lId}_$date'] = data;
      }
    }

    int daysPresent = 0, daysHalf = 0, daysAbsent = 0;
    double totalOTHours = 0;
    final attRecords = <Map<String, dynamic>>[];

    for (final data in attendance.values) {
      final status = _normalizeStatus(data['status']);
      final ot = (data['overtimeHours'] as num?)?.toDouble() ?? 0;
      if (status == 'present')     daysPresent++;
      else if (status == 'half')   daysHalf++;
      else if (status == 'absent') daysAbsent++;
      totalOTHours += ot;
      // Resolve date
      attRecords.add(data);
    }
    attRecords.sort((a, b) =>
        ((a['date'] as String?) ?? '').compareTo((b['date'] as String?) ?? ''));

    final paymentHistory = <Map<String, dynamic>>[];
    double totalAdvances = 0;
    for (final doc in _paymentDocs) {
      final data = doc.data();
      final dateValue = data['date'];
      if (!_matchesMonthValue(dateValue, monthStr)) continue;
      final type   = (data['type']   as String?) ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      if (type == 'advance') totalAdvances += amount;
      // Normalise date to DateTime for export
      DateTime? resolvedDate;
      if (dateValue is Timestamp) resolvedDate = dateValue.toDate();
      if (dateValue is DateTime)  resolvedDate = dateValue;
      if (dateValue is String)    resolvedDate = DateTime.tryParse(dateValue);
      paymentHistory.add({...data, 'id': doc.id, 'date': resolvedDate});
    }

    // Normalise attendance date fields to String
    final exportRecords = attRecords.map((r) {
      final rawDate = r['date'];
      String dateStr = '';
      if (rawDate is String)    dateStr = rawDate;
      if (rawDate is Timestamp) dateStr = rawDate.toDate().toIso8601String().substring(0, 10);
      if (rawDate is DateTime)  dateStr = rawDate.toIso8601String().substring(0, 10);
      return {...r, 'date': dateStr};
    }).toList();

    final workedDays  = daysPresent + daysHalf * 0.5;
    final grossSalary = (workedDays * _dailyWage) + (totalOTHours * _otRate);
    final netPayable  = grossSalary - totalAdvances;

    if (!mounted) return;
    setState(() {
      _loading          = false;
      _daysPresent      = daysPresent;
      _daysHalf         = daysHalf;
      _daysAbsent       = daysAbsent;
      _totalOTHours     = totalOTHours;
      _grossSalary      = grossSalary;
      _totalAdvances    = totalAdvances;
      _netPayable       = netPayable;
      _paymentHistory   = paymentHistory;
      _attendanceRecords = exportRecords;
    });
  }

  String _normalizeStatus(dynamic raw) {
    final s = (raw?.toString() ?? '').trim().toLowerCase();
    if (s == 'half_day' || s == 'half-day') return 'half';
    if (s == 'present' || s == 'absent' || s == 'half') return s;
    return '';
  }

  bool _matchesMonth(String date, String monthStr) =>
      date.startsWith(monthStr);

  bool _matchesMonthValue(dynamic value, String monthStr) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}' == monthStr;
    }
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}' == monthStr;
    }
    if (value is String) return value.startsWith(monthStr);
    return false;
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<void> _export(bool isPdf) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final svc = ReportExportService();
      final args = (
        labourName:        _labourName.isNotEmpty ? _labourName : 'Labour',
        labourId:          widget.labourId,
        month:             _month,
        year:              _year,
        daysPresent:       _daysPresent,
        daysHalf:          _daysHalf,
        daysAbsent:        _daysAbsent,
        totalOTHours:      _totalOTHours,
        dailyWage:         _dailyWage,
        otRate:            _otRate,
        grossSalary:       _grossSalary,
        totalAdvances:     _totalAdvances,
        netPayable:        _netPayable,
        paymentHistory:    _paymentHistory,
        attendanceRecords: _attendanceRecords,
      );

      if (isPdf) {
        await svc.exportPdf(
          labourName:        args.labourName,
          labourId:          args.labourId,
          month:             args.month,
          year:              args.year,
          daysPresent:       args.daysPresent,
          daysHalf:          args.daysHalf,
          daysAbsent:        args.daysAbsent,
          totalOTHours:      args.totalOTHours,
          dailyWage:         args.dailyWage,
          otRate:            args.otRate,
          grossSalary:       args.grossSalary,
          totalAdvances:     args.totalAdvances,
          netPayable:        args.netPayable,
          paymentHistory:    args.paymentHistory,
          attendanceRecords: args.attendanceRecords,
        );
      } else {
        await svc.exportExcel(
          labourName:        args.labourName,
          labourId:          args.labourId,
          month:             args.month,
          year:              args.year,
          daysPresent:       args.daysPresent,
          daysHalf:          args.daysHalf,
          daysAbsent:        args.daysAbsent,
          totalOTHours:      args.totalOTHours,
          dailyWage:         args.dailyWage,
          otRate:            args.otRate,
          grossSalary:       args.grossSalary,
          totalAdvances:     args.totalAdvances,
          netPayable:        args.netPayable,
          paymentHistory:    args.paymentHistory,
          attendanceRecords: args.attendanceRecords,
        );
      }

      if (mounted) {
        _showSnack(
          isPdf ? 'PDF downloaded successfully' : 'Excel downloaded successfully',
          AppColors.present);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Export failed: $e', AppColors.absent);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.navy));
    }

    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () async => _startStreams(),
      color: AppColors.navy,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Month Selector
          _MonthSelector(
            month: _month, year: _year,
            monthNames: _monthNames,
            canGoForward: _year < now.year ||
                (_year == now.year && _month < now.month),
            onPrev: () {
              setState(() {
                if (_month == 1) { _month = 12; _year--; } else { _month--; }
              });
              _rebuild();
            },
            onNext: () {
              setState(() {
                if (_month == 12) { _month = 1; _year++; } else { _month++; }
              });
              _rebuild();
            },
          ),
          const SizedBox(height: 14),

          // ── Export buttons ────────────────────────────────────────────
          _ExportBar(
            isExporting: _exporting,
            onPdf:   () => _export(true),
            onExcel: () => _export(false),
          ),
          const SizedBox(height: 16),

          // Attendance Summary Hero
          _AttendanceSummaryCard(
            daysPresent: _daysPresent, daysHalf: _daysHalf,
            daysAbsent: _daysAbsent, totalOTHours: _totalOTHours,
          ),
          const SizedBox(height: 16),

          // Salary Summary
          _SalarySummaryCard(
            dailyWage: _dailyWage, grossSalary: _grossSalary,
            totalAdvances: _totalAdvances, netPayable: _netPayable,
            totalOTHours: _totalOTHours, otRate: _otRate,
          ),

          // Payment History
          if (_paymentHistory.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Row(children: [
              Icon(Icons.history_rounded, size: 16, color: AppColors.textTertiary),
              SizedBox(width: 8),
              Text('PAYMENT HISTORY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 10),
            ..._paymentHistory.map((p) => _PaymentItem(data: p)),
          ],
        ],
      ),
    );
  }
}

// ── Export Bar ────────────────────────────────────────────────────────────────
class _ExportBar extends StatelessWidget {
  const _ExportBar({
    required this.isExporting,
    required this.onPdf,
    required this.onExcel,
  });

  final bool isExporting;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.download_rounded, size: 15, color: AppColors.navy),
          SizedBox(width: 7),
          Text('Export Report',
            style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 13, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 4),
        const Text('Download this month\'s report as PDF or Excel',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Row(children: [
          // PDF button
          Expanded(child: _ExportBtn(
            icon: Icons.picture_as_pdf_rounded,
            label: 'Download PDF',
            sublabel: 'Premium branded',
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
            isLoading: isExporting,
            onTap: onPdf,
          )),
          const SizedBox(width: 10),
          // Excel button
          Expanded(child: _ExportBtn(
            icon: Icons.table_chart_rounded,
            label: 'Download Excel',
            sublabel: '3-sheet workbook',
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
            isLoading: isExporting,
            onTap: onExcel,
          )),
        ]),
      ]),
    );
  }
}

class _ExportBtn extends StatelessWidget {
  const _ExportBtn({
    required this.icon, required this.label, required this.sublabel,
    required this.color, required this.bgColor,
    required this.isLoading, required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
              child: isLoading
                  ? Center(child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        color: color, strokeWidth: 2)))
                  : Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 11)),
              Text(sublabel, style: TextStyle(
                color: color.withValues(alpha: 0.65), fontSize: 9)),
            ])),
          ]),
        ),
      ),
    );
  }
}

// ── Month Selector ────────────────────────────────────────────────────────────
class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month, required this.year, required this.monthNames,
    required this.canGoForward, required this.onPrev, required this.onNext,
  });

  final int month;
  final int year;
  final List<String> monthNames;
  final bool canGoForward;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        _NavBtn(icon: Icons.chevron_left_rounded, onPressed: onPrev),
        Expanded(child: Text('${monthNames[month]} $year',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800,
            fontSize: 15, color: AppColors.textPrimary))),
        _NavBtn(icon: Icons.chevron_right_rounded,
          onPressed: canGoForward ? onNext : null),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon,
          color: enabled ? AppColors.navy : AppColors.textTertiary, size: 22)),
    );
  }
}

// ── Attendance Summary Card ───────────────────────────────────────────────────
class _AttendanceSummaryCard extends StatelessWidget {
  const _AttendanceSummaryCard({
    required this.daysPresent, required this.daysHalf,
    required this.daysAbsent, required this.totalOTHours,
  });

  final int daysPresent;
  final int daysHalf;
  final int daysAbsent;
  final double totalOTHours;

  @override
  Widget build(BuildContext context) {
    final total = daysPresent + daysHalf + daysAbsent;
    final rate  = total > 0
        ? ((daysPresent + daysHalf * 0.5) / total * 100).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF1A2438)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.3),
          blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calendar_month_rounded,
              color: AppColors.gold, size: 18),
            const SizedBox(width: 8),
            const Text('Attendance Summary',
              style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3))),
              child: Text('$rate% rate', style: const TextStyle(
                color: AppColors.gold, fontWeight: FontWeight.w700,
                fontSize: 11))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _StatItem(label: 'Present',
              count: '$daysPresent',
              icon: Icons.check_circle_rounded, color: AppColors.gold)),
            Expanded(child: _StatItem(label: 'Half Day',
              count: '$daysHalf',
              icon: Icons.schedule_rounded, color: AppColors.halfDay)),
            Expanded(child: _StatItem(label: 'Absent',
              count: '$daysAbsent',
              icon: Icons.cancel_rounded, color: AppColors.absent)),
            Expanded(child: _StatItem(label: 'OT Hours',
              count: totalOTHours.toStringAsFixed(1),
              icon: Icons.bolt_rounded, color: AppColors.goldLight)),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Attendance Rate',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
            Text('$rate%', style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: rate / 100, minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold))),
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.count,
    required this.icon, required this.color});
  final String label;
  final String count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(count, style: TextStyle(color: color,
        fontWeight: FontWeight.w900, fontSize: 18)),
      Text(label, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Salary Summary Card ───────────────────────────────────────────────────────
class _SalarySummaryCard extends StatelessWidget {
  const _SalarySummaryCard({
    required this.dailyWage, required this.grossSalary,
    required this.totalAdvances, required this.netPayable,
    required this.totalOTHours, required this.otRate,
  });

  final double dailyWage;
  final double grossSalary;
  final double totalAdvances;
  final double netPayable;
  final double totalOTHours;
  final double otRate;

  @override
  Widget build(BuildContext context) {
    final isPositive = netPayable >= 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.navy, size: 18),
            const SizedBox(width: 8),
            const Text('Salary Summary',
              style: TextStyle(fontWeight: FontWeight.w700,
                fontSize: 13, color: AppColors.textSecondary)),
          ])),
        _sRow(Icons.currency_rupee_rounded, 'Daily Wage',
          '₹${dailyWage.toStringAsFixed(0)}', AppColors.navy),
        _divider(),
        _sRow(Icons.work_outline_rounded, 'Gross Salary',
          '₹${grossSalary.toStringAsFixed(0)}', AppColors.navy),
        if (totalOTHours > 0) ...[
          _divider(),
          _sRow(Icons.bolt_rounded, 'Overtime Earned',
            '₹${(totalOTHours * otRate).toStringAsFixed(0)}',
            AppColors.halfDay),
        ],
        _divider(),
        _sRow(Icons.arrow_upward_rounded, 'Advances Taken',
          '-₹${totalAdvances.toStringAsFixed(0)}', AppColors.absent),
        Divider(color: AppColors.border),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPositive
                  ? [AppColors.navy, const Color(0xFF1F2B40)]
                  : [AppColors.absent.withValues(alpha: 0.9), AppColors.absent],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_outlined,
              color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text('Net Payable',
              style: TextStyle(fontWeight: FontWeight.w700,
                color: Colors.white, fontSize: 14))),
            Text('₹${netPayable.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                color: isPositive ? AppColors.gold : Colors.white)),
          ]),
        ),
      ]),
    );
  }

  Widget _sRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
          fontSize: 13, color: AppColors.textPrimary)),
        const Spacer(),
        Text(value, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]));
  }

  Widget _divider() =>
      Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border);
}

// ── Payment Item ──────────────────────────────────────────────────────────────
class _PaymentItem extends StatelessWidget {
  const _PaymentItem({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final type   = (data['type'] as String?) ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final dateRaw = data['date'];
    DateTime? date;
    if (dateRaw is Timestamp) date = dateRaw.toDate();
    if (dateRaw is DateTime)  date = dateRaw;
    if (dateRaw is String)    date = DateTime.tryParse(dateRaw);

    final isSalary = type != 'advance';
    final typeColor = isSalary ? AppColors.navy : AppColors.goldDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: typeColor, width: 3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(
              isSalary
                  ? Icons.payments_rounded : Icons.trending_up_rounded,
              size: 18, color: typeColor)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(type.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: typeColor, letterSpacing: 0.5)),
            if (date != null)
              Text(DateFormat('dd MMM yyyy').format(date),
                style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const Spacer(),
          Text('+₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.w800, color: typeColor)),
        ]),
      ),
    );
  }
}
