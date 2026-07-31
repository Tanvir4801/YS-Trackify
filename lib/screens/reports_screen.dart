import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/report_provider.dart';
import '../services/report_service.dart';
import '../services/telemetry_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, prov, _) => Scaffold(
        backgroundColor: const Color(0xFF10141C),
        appBar: AppBar(
          backgroundColor: const Color(0xFF10141C),
          foregroundColor: Colors.white,
          title: const Text('Reports',
            style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            // Export Excel button
            TextButton.icon(
              onPressed: prov.isLoading ? null : () => _exportExcel(prov),
              icon: const Icon(Icons.grid_on_rounded,
                color: Color(0xFFD4A437), size: 18),
              label: const Text('Export',
                style: TextStyle(color: Color(0xFFD4A437), fontSize: 12)),
            ),
          ],
        ),
        body: Column(children: [

          // Month navigator
          Container(
            color: const Color(0xFF10141C),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                  color: Colors.white70),
                onPressed: prov.previousMonth),
              Expanded(child: Center(child: Text(
                prov.summary?.monthName ??
                    '${DateTime.now().month}/${DateTime.now().year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700)))),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                  color: Colors.white70),
                onPressed: prov.nextMonth),
            ]),
          ),

          if (prov.isLoading)
            const Expanded(child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD4A437))))
          else if (prov.error != null)
            Expanded(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(prov.error!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => prov.loadReport(),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A437)),
                  child: const Text('Retry'),
                )
              ])
            ))
          else
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFD4A437),
                onRefresh: () async =>
                    prov.loadReport(month: prov.month, year: prov.year),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [

                  // Summary card
                  if (prov.summary != null)
                    _summaryCard(prov.summary!),

                  const SizedBox(height: 16),

                  // Regular labours section
                  if (prov.reports.any((r) => !r.isTemp)) ...[
                    _sectionHeader('Regular Labour',
                        prov.reports.where((r) => !r.isTemp).length),
                    const SizedBox(height: 8),
                    ...prov.reports
                        .where((r) => !r.isTemp)
                        .map((r) => _labourReportCard(r)),
                  ],

                  // Temp labours section
                  if (prov.reports.any((r) => r.isTemp)) ...[
                    const SizedBox(height: 16),
                    _sectionHeader('Temporary Labour',
                        prov.reports.where((r) => r.isTemp).length,
                        isTemp: true),
                    const SizedBox(height: 8),
                    ...prov.reports
                        .where((r) => r.isTemp)
                        .map((r) => _labourReportCard(r)),
                  ],

                  const SizedBox(height: 100),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _summaryCard(ReportSummary s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10141C), Color(0xFF1A2030)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          const Text('Monthly Summary',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD4A437).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8)),
            child: Text(s.monthName,
              style: const TextStyle(
                color: Color(0xFFD4A437),
                fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _summaryMetric('Regular', '${s.totalLabours}',
            'labours', Colors.white),
          _summaryDivider(),
          _summaryMetric('Temp', '${s.tempLabours}',
            'workers', const Color(0xFFA855F7)),
          _summaryDivider(),
          _summaryMetric('Days', s.totalDaysWorked.toStringAsFixed(1),
            'worked', const Color(0xFFD4A437)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _payRow('Gross Salary', s.totalGross, Colors.white),
            const SizedBox(height: 6),
            _payRow('Total Advances', s.totalAdvances,
              Colors.red.shade300),
            const Divider(color: Colors.white24, height: 16),
            _payRow('Net Payable', s.totalNet,
              const Color(0xFF22C55E), large: true),
          ]),
        ),
      ]),
    );
  }

  Widget _labourReportCard(LabourMonthlyReport r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2438),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: r.isTemp
              ? const Color(0xFFA855F7).withValues(alpha: 0.3)
              : const Color(0xFF2A364F)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(children: [
            // Avatar
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: r.isTemp
                    ? const Color(0xFFA855F7).withValues(alpha: 0.15)
                    : const Color(0xFF22C55E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(
                r.labourName.isNotEmpty ? r.labourName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: r.isTemp
                      ? const Color(0xFFA855F7)
                      : const Color(0xFF22C55E)))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(r.labourName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                  ),
                  if (r.isTemp) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4)),
                      child: const Text('TEMP',
                        style: TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w800,
                          color: Color(0xFFA855F7))),
                    ),
                  ],
                ]),
                Text(
                  '${r.totalDays.toStringAsFixed(1)} days · '
                  '₹${r.dailyWage}/day',
                  style: const TextStyle(
                    fontSize: 11, color: Colors.white54)),
              ],
            )),
            // Net payable
            Column(crossAxisAlignment: CrossAxisAlignment.end,
              children: [
              Text('₹${r.netPayable.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: r.netPayable >= 0
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444))),
              const Text('net payable',
                style: TextStyle(fontSize: 9, color: Colors.white54)),
            ]),
          ]),
          children: [
            // Attendance chips
            Row(children: [
              _attChip('Present', _countStatus(r, 'present'),
                const Color(0xFF22C55E), const Color(0xFF22C55E).withValues(alpha: 0.15)),
              const SizedBox(width: 6),
              _attChip('Half', _countStatus(r, 'half'),
                const Color(0xFFF59E0B), const Color(0xFFF59E0B).withValues(alpha: 0.15)),
              const SizedBox(width: 6),
              _attChip('Absent', _countStatus(r, 'absent'),
                const Color(0xFFEF4444), const Color(0xFFEF4444).withValues(alpha: 0.15)),
            ]),

            const SizedBox(height: 12),

            // Site breakdown (if multi-site)
            if (r.siteBreakdown.length > 1) ...[
              const Text('Site Breakdown',
                style: TextStyle(
                  fontSize: 11, color: Colors.white54,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...r.siteBreakdown.map((site) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.location_on,
                    size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(site.siteName,
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
                  const Spacer(),
                  Text('${site.totalFactor} days',
                    style: const TextStyle(
                      fontSize: 11, color: Colors.white54)),
                  const SizedBox(width: 8),
                  Text('₹${site.totalWage.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              )),
              const Divider(height: 16, color: Colors.white12),
            ],

            // Salary breakdown
            _salaryRow('Base Pay', r.totalWage),
            if (r.totalOTPay > 0)
              _salaryRow('Overtime Pay', r.totalOTPay,
                color: const Color(0xFFD4A437)),
            _salaryRow('Advances', r.totalAdvances,
              color: const Color(0xFFEF4444), prefix: '− '),
            const Divider(height: 12, color: Colors.white12),
            _salaryRow('Net Payable', r.netPayable,
              bold: true,
              color: r.netPayable >= 0
                  ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
          ],
        ),
      ),
    );
  }

  // Helper widgets
  Widget _summaryMetric(String label, String value,
      String sub, Color color) =>
    Expanded(child: Column(children: [
      Text(value, style: TextStyle(
        color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      Text('$label\n$sub', textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]));

  Widget _summaryDivider() => Container(
    width: 1, height: 40,
    color: Colors.white.withValues(alpha: 0.1));

  Widget _payRow(String label, double amount, Color color,
      {bool large = false}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
      Text(label, style: TextStyle(
        color: Colors.white70,
        fontSize: large ? 14 : 12,
        fontWeight: large ? FontWeight.w700 : FontWeight.w400)),
      Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(
        color: color,
        fontSize: large ? 16 : 13,
        fontWeight: FontWeight.w700)),
    ]);

  Widget _attChip(String label, int count, Color c, Color bg) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $count',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: c)));

  Widget _salaryRow(String label, double amount,
      {Color? color, bool bold = false, String prefix = ''}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        Text(label, style: TextStyle(
          fontSize: 12, color: Colors.white70,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        Text('$prefix₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? Colors.white)),
      ]));

  Widget _sectionHeader(String title, int count,
      {bool isTemp = false}) =>
    Row(children: [
      if (isTemp) const Icon(Icons.bolt,
        size: 16, color: Color(0xFFA855F7)),
      const SizedBox(width: 4),
      Text(title, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: isTemp
            ? const Color(0xFFA855F7) : Colors.white)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isTemp
              ? const Color(0xFFA855F7).withValues(alpha: 0.15)
              : const Color(0xFF22C55E).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
        child: Text('$count', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: isTemp
              ? const Color(0xFFA855F7)
              : const Color(0xFF22C55E)))),
    ]);

  int _countStatus(LabourMonthlyReport r, String status) {
    int count = 0;
    r.attendanceByDate.forEach((_, records) {
      count += records.where((rec) => rec['status'] == status).length;
    });
    return count;
  }

  Future<void> _exportExcel(ReportsProvider prov) async {
    TelemetryService.instance.trackFeatureUsage('Export Excel');
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel export is not supported on web.')),
        );
        return;
      }
      final path = await ReportService().exportToExcel(prov.month, prov.year);
      await Share.shareXFiles([XFile(path)], text: 'Monthly Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting Excel: $e')),
      );
    }
  }
}
