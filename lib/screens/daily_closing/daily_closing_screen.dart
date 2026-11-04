import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';
import '../../models/daily_closing_report.dart';
import '../../providers/closing_report_provider.dart';
import '../../providers/sites_provider.dart';
import '../../services/closing_report_service.dart';
import 'package:intl/intl.dart';
import '../closing_report/widgets/action_button_bar.dart';
import '../closing_report/widgets/insight_chip.dart';
import '../closing_report/widgets/report_section_card.dart';
import '../closing_report/widgets/report_stat_row.dart';

class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> {
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateReport();
    });
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    
    final closingProv = context.read<ClosingReportProvider>();
    final sitesProv = context.read<SitesProvider>();
    
    // We assume the first site for the contractor for now if not passed
    final site = sitesProv.sites.isNotEmpty ? sitesProv.sites.first : null;
    final siteId = site?.id ?? 'default_site';
    final siteName = site?.name ?? 'Main Site';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await closingProv.generateReport(
        siteId: siteId,
        siteName: siteName,
        date: today,
      );
    } catch (e) {
      debugPrint('Error generating closing report: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _shareToWhatsApp(DailyClosingReport report) {
    HapticUtils.light();
    final msg = ClosingReportService().formatWhatsAppMessage(report);
    Share.share(msg, subject: 'Daily Closing Report - ${report.date}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text('Daily Closing', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Consumer<ClosingReportProvider>(
        builder: (context, prov, _) {
          if (_isGenerating || prov.isGenerating) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context)));
          }

          final report = prov.currentReport;
          if (report == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_late_rounded, size: 64, color: AppColors.textTertiaryColor(context)),
                  const SizedBox(height: 16),
                  Text('No report generated yet', style: TextStyle(color: AppColors.textSecondaryColor(context))),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _generateReport,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primaryColor(context), foregroundColor: AppColors.backgroundColor(context)),
                    child: const Text('Generate Now'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildOverviewCard(report),
              const SizedBox(height: 16),
              _buildAttendanceCard(report),
              const SizedBox(height: 16),
              _buildCostCard(report),
              const SizedBox(height: 16),
              _buildInsights(report),
              if (report.isSynced)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.successColor(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.successColor(context).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, color: AppColors.successColor(context), size: 20),
                      const SizedBox(width: 8),
                      Text('Day Locked & Synced', style: TextStyle(color: AppColors.successColor(context), fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: prov.isSaving ? null : () async {
                    HapticUtils.success();
                    final success = await prov.saveReport();
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Day Locked Successfully!')));
                      Navigator.pop(context);
                    }
                  },
                  icon: prov.isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_rounded),
                  label: Text(prov.isSaving ? 'Locking...' : 'Confirm & Lock Day'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryColor(context),
                  ),
                ),
              const SizedBox(height: 24),
              ActionButtonBar(
                onWhatsApp: () => _shareToWhatsApp(report),
                onDownloadPdf: () {}, // Implementation coming soon
                onCopy: () {}, // Implementation coming soon
                onSave: () async {
                  HapticUtils.success();
                  await prov.saveReport();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report saved locally!')));
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(DailyClosingReport report) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryColor(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('Total Site Cost Today', style: TextStyle(color: AppColors.primaryColor(context), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            '₹${report.totalExpense.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimaryColor(context), letterSpacing: -1),
          ),
          const SizedBox(height: 4),
          Text(report.date, style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(DailyClosingReport report) {
    return ReportSectionCard(
      title: 'Attendance Summary',
      icon: Icons.groups_rounded,
      iconColor: AppColors.infoColor(context),
      child: Column(
        children: [
          ReportStatRow(label: 'Total Active Labour', value: '${report.totalLabourCount}'),
          Divider(color: AppColors.borderColor(context), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _miniStat('Present', '${report.presentCount}', AppColors.successColor(context)),
              _miniStat('0.75', '${report.threeQuarterCount}', AppColors.infoColor(context)),
              _miniStat('Half', '${report.halfDayCount}', AppColors.warningColor(context)),
              _miniStat('0.25', '${report.quarterCount}', AppColors.infoColor(context)),
              _miniStat('Absent', '${report.absentCount}', AppColors.errorColor(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostCard(DailyClosingReport report) {
    return ReportSectionCard(
      title: 'Cost Breakdown',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: AppColors.primaryColor(context),
      child: Column(
        children: [
          ReportStatRow(label: 'Labour Wages', value: '₹${report.totalLabourCost.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          ReportStatRow(label: 'Allowances & Advance', value: '₹${(report.totalAllowances + report.totalAdvance).toStringAsFixed(0)}'),
          if (report.totalMaterialCost > 0) ...[
            const SizedBox(height: 12),
            ReportStatRow(label: 'Material Purchases', value: '₹${report.totalMaterialCost.toStringAsFixed(0)}'),
          ],
          if (report.totalMachineryCost > 0) ...[
            const SizedBox(height: 12),
            ReportStatRow(label: 'Machinery Expenses', value: '₹${report.totalMachineryCost.toStringAsFixed(0)}'),
          ],
          if (report.totalTransportCost > 0) ...[
            const SizedBox(height: 12),
            ReportStatRow(label: 'Transport Expenses', value: '₹${report.totalTransportCost.toStringAsFixed(0)}'),
          ],
          if (report.totalOtherCost > 0) ...[
            const SizedBox(height: 12),
            ReportStatRow(label: 'Other Expenses', value: '₹${report.totalOtherCost.toStringAsFixed(0)}'),
          ],
          Divider(color: AppColors.borderColor(context), height: 24),
          ReportStatRow(label: 'Total Expenses', value: '₹${report.totalExpense.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _buildInsights(DailyClosingReport report) {
    if (report.insights.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('AI Insights', style: TextStyle(color: AppColors.textSecondaryColor(context), fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
        ),
        ...report.insights.map((insight) => InsightChip(text: insight)),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiaryColor(context), fontWeight: FontWeight.w600)),
      ],
    );
  }
}
