import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization/app_text.dart';
import '../core/theme/app_colors.dart';
import '../models/labour_report_summary.dart';
import '../providers/site_data_provider.dart';
import '../services/export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ExportService _exportService = ExportService();
  final TextEditingController _searchController = TextEditingController();
  bool _isExporting = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _backupData(SiteDataProvider data) async {
    if (_isExporting) {
      return;
    }

    setState(() => _isExporting = true);
    final result = await _exportService.exportBackupJson(
      labours: data.labours,
      attendance: data.hiveService.getAllAttendanceRecords(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isExporting = false);

    if (!result.isSuccess || result.file == null) {
      _showMessage(result.error ?? 'Backup failed');
      return;
    }

    _showMessage('Backup saved: ${result.file!.path}');
    await _exportService.shareFile(result.file!);
  }

  Future<void> _exportExcel(SiteDataProvider data) async {
    if (_isExporting) {
      return;
    }

    setState(() => _isExporting = true);

    final reports = data.buildLabourReport();

    final result = await _exportService.exportLabourExcel(
      labours: data.labours,
      attendanceRecords: data.hiveService.getAllAttendanceRecords(),
      reports: reports,
    );

    if (!mounted) {
      return;
    }
    setState(() => _isExporting = false);

    if (!result.isSuccess || result.file == null) {
      _showMessage(
          result.error ?? 'Excel export failed. Please check permissions.');
      return;
    }

    _showSavedWithShare(
        result.file!.path, () => _exportService.shareFile(result.file!));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSavedWithShare(String path, Future<void> Function() onShare) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('File saved successfully\n$path'),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () {
            onShare();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteDataProvider>(
      builder: (context, data, _) {
        final reports = data.buildLabourReport();
        final filteredReports = reports.where((item) {
          final query = _searchQuery.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return item.labourName.toLowerCase().contains(query);
        }).toList();

        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isExporting ? null : () => _backupData(data),
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Backup Data'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isExporting ? null : () => _exportExcel(data),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Export Excel'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search by person name',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              Expanded(
                child: reports.isEmpty
                    ? Center(child: Text(context.tr('noReportData')))
                    : filteredReports.isEmpty
                        ? const Center(
                            child: Text('No person found for this name'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filteredReports.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filteredReports[index];
                              return _ReportTile(item: item);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.item});

  final LabourReportSummary item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.labourName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              item.role,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.72),
                  ),
            ),
            const Divider(height: 20),
            _SectionHeader(
              icon: Icons.fact_check_outlined,
              title: 'Attendance',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _chip('${context.tr('present')}: ${item.presentDays}', AppColors.present),
                _chip('${context.tr('half')}: ${item.halfDays}', AppColors.halfDay),
                _chip('${context.tr('absent')}: ${item.absentDays}', AppColors.absent),
              ],
            ),
            const SizedBox(height: 10),
            _summaryRow(
              context,
              label: context.tr('workdays'),
              value: item.effectiveWorkdays.toStringAsFixed(1),
            ),
            const Divider(height: 24),
            _SectionHeader(
              icon: Icons.currency_rupee,
              title: 'Earnings',
            ),
            const SizedBox(height: 8),
            _summaryRow(
              context,
              label: context.tr('basePay'),
              value: 'Rs ${item.totalEarned.toStringAsFixed(0)}',
              valueStyle: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            _summaryRow(
              context,
              label: context.tr('overtimePay'),
              value: 'Rs ${item.overtimePay.toStringAsFixed(0)}',
              valueStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
            const Divider(height: 24),
            _SectionHeader(
              icon: Icons.remove_circle_outline,
              title: 'Deductions',
            ),
            const SizedBox(height: 8),
            _summaryRow(
              context,
              label: context.tr('advance'),
              value: 'Rs ${item.advanceAmount.toStringAsFixed(0)}',
              valueStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.absent,
              ),
            ),
            const Divider(height: 24),
            _SectionHeader(
              icon: Icons.verified_outlined,
              title: context.tr('finalPay'),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F9EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    context.tr('finalPay'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs ${item.finalPay.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.present,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    final baseValueStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: baseValueStyle?.merge(valueStyle) ?? valueStyle,
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide.none,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      label: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}
