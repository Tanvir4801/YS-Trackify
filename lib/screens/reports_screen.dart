import '../core/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/report_provider.dart';
import '../providers/branding_provider.dart';
import '../services/report_service.dart';
import '../services/telemetry_service.dart';
import '../services/session_service.dart';
import '../services/report_pdf_service.dart';
import '../utils/error_handler.dart';
import '../widgets/glass_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundColor(context) : Colors.transparent;

    return Consumer<ReportsProvider>(
      builder: (context, prov, _) => Container(
        decoration: isDark ? BoxDecoration(color: AppColors.backgroundColor(context)) : const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF4F7FB),
              Color(0xFFF0F4F8),
              Color(0xFFF4F7FB),
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            foregroundColor: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF102A4C),
          title: Text('Reports',
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF0B3157))),
          actions: [
            // Export button
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
              child: GlassCard(
                useBlur: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                borderRadius: 20,
                baseColorTint: isDark ? null : const Color(0xFFFFF9E6),
                onTap: prov.isLoading ? null : () => _showExportOptions(prov),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded, color: const Color(0xFFF5A900), size: 16),
                    const SizedBox(width: 6),
                    Text('Export', style: TextStyle(color: const Color(0xFFF5A900), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(children: [
          // Month navigator
          Container(
            color: bgColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.chevron_left,
                      color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6F89A6)),
                  onPressed: prov.previousMonth),
              Expanded(
                  child: Center(
                      child: Text(
                          prov.summary?.monthName ??
                              '${DateTime.now().month}/${DateTime.now().year}',
                          style: TextStyle(
                              color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF102A4C),
                              fontSize: 16,
                              fontWeight: FontWeight.w700)))),
              IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6F89A6)),
                  onPressed: prov.nextMonth),
            ]),
          ),

          if (prov.isLoading)
            Expanded(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryColor(context))))
          else if (prov.error != null)
            Expanded(
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline,
                  color: AppColors.errorColor(context), size: 48),
              const SizedBox(height: 16),
              Text(prov.error!,
                  style: TextStyle(
                      color: AppColors.textPrimaryColor(context),
                      fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => prov.loadReport(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor(context)),
                child: const Text('Retry'),
              )
            ])))
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryColor(context),
                onRefresh: () async =>
                    prov.loadReport(month: prov.month, year: prov.year),
                child: ListView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.all(16), children: [
                  // Summary card
                  if (prov.summary != null) _summaryCard(prov.summary!),

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

                  // Empty State when no labours had records for this month
                  if (prov.reports.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.assessment_outlined, size: 48, color: isDark ? Colors.white38 : const Color(0xFF91AAC8)),
                            const SizedBox(height: 12),
                            Text('No records for this month', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF102A4C))),
                            const SizedBox(height: 4),
                            Text('Attendance or payments marked for this month will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF6F89A6))),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
        ]),
        ),
      ),
    );
  }

  Widget _summaryCard(ReportSummary s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      useBlur: true,
      padding: const EdgeInsets.all(20),
      borderRadius: 26.0,
      baseColorTint: isDark ? null : Colors.white,
      tintOpacityLight: 0.85,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Monthly Summary',
              style: TextStyle(
                  color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6F89A6), fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: isDark ? AppColors.primaryColor(context).withValues(alpha: 0.2) : const Color(0xFFFFF5D9),
                borderRadius: BorderRadius.circular(8)),
            child: Text(s.monthName,
                style: TextStyle(
                    color: isDark ? AppColors.primaryColor(context) : const Color(0xFFF2A900),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _summaryMetric('Regular', '${s.totalLabours}', 'labours', Icons.people_alt,
              isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF00A878), isDark ? null : const Color(0xFFE3F7EE)),
          _summaryDivider(isDark),
          _summaryMetric('Temp', '${s.tempLabours}', 'workers', Icons.person_outline,
              AppColors.violetColor(context), isDark ? null : const Color(0xFFF0E7FF)),
          _summaryDivider(isDark),
          _summaryMetric('Days', s.totalDaysWorked.toStringAsFixed(1), 'worked', Icons.calendar_today_rounded,
              isDark ? AppColors.primaryColor(context) : const Color(0xFFF2A900), isDark ? null : const Color(0xFFFFF5D9)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedColor(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _payRow('Gross Salary', s.totalGross,
                isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF102A4C), isDark),
            const SizedBox(height: 6),
            _payRow('Total Advances', s.totalAdvances,
                isDark ? AppColors.errorColor(context) : const Color(0xFFF43F5E), isDark),
            Divider(color: isDark ? AppColors.borderColor(context) : const Color(0xFFD8E5F2), height: 16),
            _payRow('Net Payable', s.totalNet, isDark ? AppColors.successColor(context) : const Color(0xFF00A878), isDark,
                large: true),
          ]),
        ),
      ]),
    );
  }

  Widget _labourReportCard(LabourMonthlyReport r) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        useBlur: true,
        padding: EdgeInsets.zero,
        borderRadius: 24.0,
        baseColorTint: isDark 
            ? (r.isTemp ? AppColors.violetColor(context) : null) 
            : (r.isTemp ? const Color(0xFFF6F0FA) : const Color(0xFFEBFAF7)),
        tintOpacityLight: 0.72,
        glowColor: isDark && r.isTemp ? AppColors.violetColor(context) : null,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: isDark ? null : const Color(0xFFD4F0E2).withValues(alpha: 0.4),
          dense: true,
          visualDensity: const VisualDensity(vertical: -4),
          tilePadding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: isDark 
                      ? (r.isTemp ? AppColors.violetColor(context).withValues(alpha: 0.15) : AppColors.successColor(context).withValues(alpha: 0.15))
                      : const Color(0xFFDDF7EF),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(
                      r.labourName.isNotEmpty
                          ? r.labourName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark 
                              ? (r.isTemp ? AppColors.violetColor(context) : AppColors.successColor(context))
                              : const Color(0xFF00A878)))),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(r.labourName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF102A4C))),
                  ),
                  if (r.isTemp) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: isDark ? AppColors.violetColor(context).withValues(alpha: 0.15) : const Color(0xFFF0E7FF),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('TEMP',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AppColors.violetColor(context))),
                    ),
                  ],
                ]),
                Text(
                    '${r.totalDays.toStringAsFixed(1)} days · '
                    '₹${r.dailyWage}/day',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textTertiaryColor(context) : const Color(0xFF6F89A6))),
              ],
            )),
            // Net payable
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${r.netPayable.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark 
                          ? (r.netPayable >= 0 ? AppColors.successColor(context) : AppColors.errorColor(context))
                          : (r.netPayable >= 0 ? const Color(0xFF00A878) : const Color(0xFFF43F5E)))),
              Text('NET PAYABLE',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textTertiaryColor(context) : const Color(0xFF6F89A6))),
            ]),
          ]),
          children: [
            // Attendance chips
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (_countStatus(r, 'present') > 0)
                _attChip(
                    '1.0',
                    _countStatus(r, 'present'),
                    isDark ? AppColors.successColor(context) : const Color(0xFF00A878),
                    isDark ? AppColors.successColor(context).withValues(alpha: 0.15) : const Color(0xFFDDF7EF)),
              if (_countStatus(r, 'three_quarter') > 0)
                _attChip(
                    '0.75',
                    _countStatus(r, 'three_quarter'),
                    isDark ? AppColors.infoColor(context) : const Color(0xFF008C95),
                    isDark ? AppColors.infoColor(context).withValues(alpha: 0.15) : const Color(0xFFE2F5F7)),
              if (_countStatus(r, 'half') > 0)
                _attChip(
                    '0.5',
                    _countStatus(r, 'half'),
                    isDark ? AppColors.warningColor(context) : const Color(0xFFD88A00),
                    isDark ? AppColors.warningColor(context).withValues(alpha: 0.15) : const Color(0xFFFFF5D9)),
              if (_countStatus(r, 'quarter') > 0)
                _attChip(
                    '0.25',
                    _countStatus(r, 'quarter'),
                    AppColors.violetColor(context),
                    isDark ? AppColors.violetColor(context).withValues(alpha: 0.15) : const Color(0xFFF0E7FF)),
              if (_countStatus(r, 'absent') > 0)
                _attChip(
                    '0.0',
                    _countStatus(r, 'absent'),
                    isDark ? AppColors.errorColor(context) : const Color(0xFFF43F5E),
                    isDark ? AppColors.errorColor(context).withValues(alpha: 0.15) : const Color(0xFFFCE7ED)),
            ]),

            const SizedBox(height: 12),

            // Site breakdown
            if (r.siteBreakdown.isNotEmpty) ...[
              Text('Site Breakdown',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textTertiaryColor(context) : const Color(0xFF6F89A6),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...r.siteBreakdown.map((site) {
                final List<String> details = [];
                if (site.presentCount > 0) details.add('1.0: ${site.presentCount}');
                if (site.threeQuarterCount > 0) details.add('0.75: ${site.threeQuarterCount}');
                if (site.halfCount > 0) details.add('0.5: ${site.halfCount}');
                if (site.quarterCount > 0) details.add('0.25: ${site.quarterCount}');
                final detailStr = details.isNotEmpty ? details.join(', ') : '${site.totalFactor} days';

                return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.location_on,
                          size: 12,
                          color: isDark ? AppColors.textTertiaryColor(context) : const Color(0xFF6F89A6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(site.siteName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF102A4C))),
                      ),
                      const SizedBox(width: 8),
                      Text(detailStr,
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textTertiaryColor(context) : const Color(0xFF6F89A6))),
                      const SizedBox(width: 8),
                      Text('₹${site.totalWage.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF102A4C))),
                    ]));
              }),
              const SizedBox(height: 12),
              Container(height: 1, color: isDark ? AppColors.surfaceElevatedColor(context) : const Color(0xFFD8E5F2)),
              const SizedBox(height: 12),
            ],

            // Salary breakdown
            _salaryRow('Base Pay', r.totalWage, isDark: isDark),
            if (r.totalOTPay > 0)
              _salaryRow('Overtime Pay', r.totalOTPay,
                  color: isDark ? AppColors.primaryColor(context) : const Color(0xFFF2A900), isDark: isDark),
            _salaryRow('Advances', r.totalAdvances,
                color: isDark ? AppColors.errorColor(context) : const Color(0xFFF43F5E), prefix: '− ', isDark: isDark),
            Divider(height: 12, color: isDark ? AppColors.subtleBorderColor(context) : const Color(0xFFD8E5F2)),
            _salaryRow('Net Payable', r.netPayable,
                bold: true,
                color: isDark 
                    ? (r.netPayable >= 0 ? AppColors.successColor(context) : AppColors.errorColor(context))
                    : (r.netPayable >= 0 ? const Color(0xFF00A878) : const Color(0xFFF43F5E)),
                isDark: isDark),
          ],
        ),
      ),
      ),
    );
  }

  // Helper widgets
  Widget _summaryMetric(String label, String value, String sub, IconData icon, Color color, Color? bg) =>
      Expanded(
          child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (bg != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
            ],
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        Text('$label\n$sub',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.textTertiaryColor(context) : const Color(0xFF6F89A6), fontSize: 11)),
      ]));

  Widget _summaryDivider(bool isDark) => Container(
      width: 1, height: 40, color: isDark ? AppColors.surfaceElevatedColor(context) : const Color(0xFFD8E5F2));

  Widget _payRow(String label, double amount, Color color, bool isDark,
          {bool large = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6F89A6),
                fontSize: large ? 14 : 12,
                fontWeight: large ? FontWeight.w700 : FontWeight.w400)),
        Text('₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                color: color,
                fontSize: large ? 16 : 13,
                fontWeight: FontWeight.w700)),
      ]);

  Widget _attChip(String label, int count, Color c, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
      child: Text(
          '$label: $count',
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)));

  Widget _salaryRow(String label, double amount,
          {Color? color, bool bold = false, String prefix = '', required bool isDark}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6F89A6),
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
            Text('$prefix₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: bold ? 14 : 12,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: color ?? (isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF102A4C)))),
          ]));

  Widget _sectionHeader(String title, int count, {bool isTemp = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(children: [
      if (isTemp)
        Icon(Icons.bolt, size: 16, color: AppColors.violetColor(context)),
      const SizedBox(width: 4),
      Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? (isTemp ? AppColors.violetColor(context) : AppColors.textPrimaryColor(context))
                  : (isTemp ? const Color(0xFF7C3AED) : const Color(0xFF0B3157)))),
      const SizedBox(width: 6),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: isDark
                  ? (isTemp ? AppColors.violetColor(context).withValues(alpha: 0.15) : AppColors.successColor(context).withValues(alpha: 0.15))
                  : (isTemp ? const Color(0xFFF0E7FF) : const Color(0xFFE3F7EE)),
              borderRadius: BorderRadius.circular(8)),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? (isTemp ? AppColors.violetColor(context) : AppColors.successColor(context))
                      : (isTemp ? const Color(0xFF7C3AED) : const Color(0xFF00B686))))),
    ]);
  }

  int _countStatus(LabourMonthlyReport r, String status) {
    int count = 0;
    r.attendanceByDate.forEach((_, records) {
      count += records.where((rec) => rec['status'] == status).length;
    });
    return count;
  }

  void _showExportOptions(ReportsProvider prov) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceElevatedColor(context) : const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Export Monthly Report',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF102A4C))),
              const SizedBox(height: 8),
              Text(prov.summary?.monthName ?? '',
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6F89A6))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.check_circle, color: isDark ? AppColors.successColor(context) : const Color(0xFF00A878), size: 16),
                  const SizedBox(width: 8),
                  const Text('Site summary', style: TextStyle(fontSize: 13)),
                ]
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: isDark ? AppColors.successColor(context) : const Color(0xFF00A878), size: 16),
                  const SizedBox(width: 8),
                  const Text('Labour-wise attendance', style: TextStyle(fontSize: 13)),
                ]
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: isDark ? AppColors.successColor(context) : const Color(0xFF00A878), size: 16),
                  const SizedBox(width: 8),
                  const Text('Date-wise attendance & Salary details', style: TextStyle(fontSize: 13)),
                ]
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportPdf(prov);
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generate PDF'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isDark ? AppColors.primaryColor(context) : const Color(0xFF102A4C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _exportPdf(ReportsProvider prov) async {
    if (prov.summary == null) return;
    TelemetryService.instance.trackFeatureUsage('Export PDF Monthly');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating report...\nPlease wait.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    try {
      final branding = context.read<BrandingProvider>().branding;
      final session = SessionService.instance;
      final supervisorName = session.name ?? session.current?.phone ?? 'Supervisor';

      final file = await ReportPdfService.generate(
        summary: prov.summary!,
        reports: prov.reports,
        branding: branding,
        supervisorName: supervisorName,
      );

      if (mounted) Navigator.pop(context); // close loading

      await Share.shareXFiles([XFile(file.path)], text: 'Monthly Report - ${prov.summary!.monthName}');
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _exportExcel(ReportsProvider prov) async {
    TelemetryService.instance.trackFeatureUsage('Export Excel');
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Excel export is not supported on web.')),
        );
        return;
      }
      final path = await ReportService().exportToExcel(prov.month, prov.year);
      await Share.shareXFiles([XFile(path)], text: 'Monthly Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
      );
    }
  }
}
