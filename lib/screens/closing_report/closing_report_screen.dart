import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/daily_closing_report.dart';
import '../../providers/closing_report_provider.dart';
import '../../providers/sites_provider.dart';
import '../../services/session_service.dart';
import '../../widgets/animations/staggered_list.dart';
import 'widgets/action_button_bar.dart';
import 'widgets/insight_chip.dart';
import 'widgets/report_section_card.dart';
import 'widgets/report_stat_row.dart';

class ClosingReportScreen extends StatefulWidget {
  const ClosingReportScreen({super.key, this.initialSiteId});

  final String? initialSiteId;

  @override
  State<ClosingReportScreen> createState() => _ClosingReportScreenState();
}

class _ClosingReportScreenState extends State<ClosingReportScreen> {
  String? _selectedSiteId;
  String? _selectedSiteName;
  bool _isRainHoliday = false;
  final _remarksController = TextEditingController();
  final _remarksFocus = FocusNode();
  bool _hasGenerated = false;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.initialSiteId;
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _remarksFocus.dispose();
    super.dispose();
  }

  void _generateReport() {
    if (_selectedSiteId == null || _selectedSiteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a site first'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    context.read<ClosingReportProvider>().generateReport(
          siteId: _selectedSiteId!,
          siteName: _selectedSiteName ?? 'Site',
          date: today,
          isRainHoliday: _isRainHoliday,
        );

    setState(() => _hasGenerated = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Consumer<ClosingReportProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: provider.isGenerating
                    ? _buildLoadingState()
                    : provider.currentReport != null && _hasGenerated
                        ? _buildReportPreview(provider.currentReport!)
                        : _buildSetupForm(),
              ),
              if (provider.currentReport != null && _hasGenerated)
                ActionButtonBar(
                  onWhatsApp: () => _handleAction(
                    context,
                    () => provider.shareWhatsApp(),
                    'Shared successfully!',
                  ),
                  onDownloadPdf: () => _handleAction(
                    context,
                    () => provider.downloadPdf(),
                    'PDF downloaded!',
                  ),
                  onCopy: () => _handleAction(
                    context,
                    () => provider.copyReport(),
                    'Report copied to clipboard!',
                  ),
                  onSave: () async {
                    final success = await provider.saveReport();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Report saved successfully!'
                              : 'Failed to save report',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor:
                            success ? AppColors.present : AppColors.absent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  isSaving: provider.isSaving,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.present,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.absent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Site Closing Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Premium Report Generator',
                      style: TextStyle(
                        color: AppColors.textOnDarkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, AppColors.goldLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        color: AppColors.navy, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Setup Form ────────────────────────────────────────────────────────────

  Widget _buildSetupForm() {
    return Consumer<SitesProvider>(
      builder: (context, sitesProvider, _) {
        final sites = sitesProvider.sites.where((s) => s.isActive).toList();

        // Auto-select site if only one
        if (sites.length == 1 &&
            _selectedSiteId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedSiteId = sites.first.id;
              _selectedSiteName = sites.first.name;
            });
          });
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),

            // Site selector
            StaggeredFadeIn(
              index: 0,
              child: _buildSiteSelector(sites),
            ),

            const SizedBox(height: 16),

            // Rain holiday toggle
            StaggeredFadeIn(
              index: 1,
              child: _buildRainHolidayToggle(),
            ),

            const SizedBox(height: 16),

            // Supervisor remarks
            StaggeredFadeIn(
              index: 2,
              child: _buildRemarksInput(),
            ),

            const SizedBox(height: 24),

            // Generate button
            StaggeredFadeIn(
              index: 3,
              child: _buildGenerateButton(),
            ),

            const SizedBox(height: 16),

            // Info card
            StaggeredFadeIn(
              index: 4,
              child: _buildInfoCard(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSiteSelector(List sites) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: AppColors.gold, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'SELECT SITE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSiteId,
                isExpanded: true,
                hint: const Text('Choose a site',
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 14)),
                icon: const Icon(Icons.expand_more_rounded,
                    color: AppColors.textSecondary),
                items: sites
                    .map((site) => DropdownMenuItem<String>(
                          value: site.id,
                          child: Text(site.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
                onChanged: (value) {
                  final site = sites.firstWhere((s) => s.id == value);
                  setState(() {
                    _selectedSiteId = value;
                    _selectedSiteName = site.name;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRainHolidayToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.cloud_rounded,
                color: AppColors.blue, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rain Holiday',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Mark if site was affected by rain',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isRainHoliday,
            onChanged: (val) => setState(() => _isRainHoliday = val),
            activeThumbColor: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.present.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: AppColors.present, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'SUPERVISOR NOTES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Optional',
                    style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remarksController,
            focusNode: _remarksFocus,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'Add notes about today\'s work...\ne.g., Cement delivery completed\nNeed 5 labourers tomorrow',
              hintStyle: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 13),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.gold, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: () {
        // Apply remarks before generating
        if (_remarksController.text.isNotEmpty) {
          context
              .read<ClosingReportProvider>()
              .setSupervisorRemarks(_remarksController.text);
        }
        _generateReport();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.navy, AppColors.navyLight],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 20),
            SizedBox(width: 10),
            Text(
              'Generate Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Report will include today\'s attendance, expenses, labour details, and smart insights.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading State ─────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              backgroundColor: AppColors.gold.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Generating Report...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Analyzing today\'s data',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Report Preview ────────────────────────────────────────────────────────

  Widget _buildReportPreview(DailyClosingReport report) {
    // Apply remarks if set after generation
    if (_remarksController.text.isNotEmpty &&
        report.supervisorRemarks.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context
            .read<ClosingReportProvider>()
            .setSupervisorRemarks(_remarksController.text);
      });
    }

    final currency = NumberFormat('#,##0', 'en_IN');
    String displayDate;
    try {
      displayDate =
          DateFormat('d MMMM yyyy').format(DateTime.parse(report.date));
    } catch (_) {
      displayDate = report.date;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Site info header
        StaggeredFadeIn(
          index: 0,
          child: _buildSiteInfoHeader(report, displayDate),
        ),

        const SizedBox(height: 16),

        // Attendance Summary
        StaggeredFadeIn(
          index: 1,
          child: ReportSectionCard(
            title: 'ATTENDANCE SUMMARY',
            icon: Icons.groups_rounded,
            iconColor: AppColors.blue,
            child: Column(
              children: [
                Row(
                  children: [
                    _miniStatCard(
                        '${report.presentCount}', 'Present', AppColors.present),
                    const SizedBox(width: 10),
                    _miniStatCard(
                        '${report.absentCount}', 'Absent', AppColors.absent),
                    const SizedBox(width: 10),
                    _miniStatCard(
                        '${report.halfDayCount}', 'Half Day', AppColors.halfDay),
                  ],
                ),
                const SizedBox(height: 14),
                // Attendance rate bar
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Attendance Rate',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        Text(
                          '${report.attendancePercentage.round()}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            (report.attendancePercentage / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceMuted,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.gold),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Expense Summary
        StaggeredFadeIn(
          index: 2,
          child: ReportSectionCard(
            title: 'EXPENSE SUMMARY',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.gold,
            child: Column(
              children: [
                ReportStatRow(
                  label: 'Labour Cost',
                  value: '\u20b9${currency.format(report.totalLabourCost)}',
                ),
                ReportStatRow(
                  label: 'Advance Given',
                  value: '\u20b9${currency.format(report.totalAdvance)}',
                  valueColor: AppColors.halfDay,
                ),
                ReportStatRow(
                  label: 'Allowances',
                  value: '\u20b9${currency.format(report.totalAllowances)}',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, AppColors.navyLight],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL EXPENSE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '\u20b9${currency.format(report.totalExpense)}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Labour Details
        StaggeredFadeIn(
          index: 3,
          child: ReportSectionCard(
            title: 'LABOUR DETAILS',
            icon: Icons.engineering_rounded,
            iconColor: AppColors.navy,
            child: Column(
              children: [
                ReportStatRow(
                  label: 'Total Labour',
                  value: '${report.totalLabourCount}',
                  isBold: true,
                ),
                ReportStatRow(
                  label: 'New Labour Today',
                  value: '${report.newLabourCount}',
                  valueColor: report.newLabourCount > 0
                      ? AppColors.present
                      : AppColors.textPrimary,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),

        // Smart Insights
        if (report.insights.isNotEmpty)
          StaggeredFadeIn(
            index: 4,
            child: ReportSectionCard(
              title: 'SMART INSIGHTS',
              icon: Icons.insights_rounded,
              iconColor: AppColors.gold,
              child: Column(
                children: report.insights
                    .asMap()
                    .entries
                    .map((e) => InsightChip(
                          text: e.value,
                          index: e.key,
                        ))
                    .toList(),
              ),
            ),
          ),

        // Supervisor Remarks
        StaggeredFadeIn(
          index: 5,
          child: ReportSectionCard(
            title: 'SUPERVISOR NOTES',
            icon: Icons.edit_note_rounded,
            iconColor: AppColors.present,
            child: report.supervisorRemarks.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: report.supervisorRemarks
                        .split('\n')
                        .where((l) => l.trim().isNotEmpty)
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('\u2022 ',
                                    style: TextStyle(
                                        color: AppColors.gold,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                Expanded(
                                  child: Text(
                                    line.trim(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  )
                : TextField(
                    controller: _remarksController,
                    maxLines: 3,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Add notes about today\'s work...',
                      hintStyle: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.gold, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    onChanged: (val) {
                      context
                          .read<ClosingReportProvider>()
                          .setSupervisorRemarks(val);
                    },
                  ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSiteInfoHeader(DailyClosingReport report, String displayDate) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: AppColors.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.siteName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayDate,
                      style: const TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.present.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.present, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'READY',
                      style: TextStyle(
                        color: AppColors.present,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Row(
            children: [
              _metaItem(Icons.person_rounded, 'Supervisor',
                  report.supervisorName.isNotEmpty ? report.supervisorName : SessionService.instance.name ?? 'Supervisor'),
              const SizedBox(width: 16),
              _metaItem(Icons.access_time_rounded, 'Generated',
                  DateFormat('hh:mm a').format(DateTime.now())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: AppColors.goldLight, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
