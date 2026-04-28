import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/localization/app_text.dart';
import '../core/theme/app_colors.dart';
import '../models/labour_report_summary.dart';
import '../providers/report_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadReport();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _backupData(ReportProvider data) async {
    if (data.isBackingUp || data.isExporting) {
      return;
    }

    await data.backupData();
    if (!mounted) {
      return;
    }

    if (data.error != null) {
      _showMessage(data.error!);
      return;
    }

    _showMessage('Backup completed successfully');
  }

  Future<void> _exportExcel(ReportProvider data) async {
    if (data.isExporting || data.isBackingUp) {
      return;
    }

    await data.exportExcel();
    if (!mounted) {
      return;
    }

    if (data.error != null) {
      _showMessage(data.error!);
      return;
    }

    if (data.exportedFilePath != null) {
      _showMessage('File saved: ${data.exportedFilePath}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, data, _) {
        final reports = data.summaries;
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
                        onPressed: (data.isExporting || data.isBackingUp)
                            ? null
                            : () => _backupData(data),
                        icon: const Icon(Icons.backup_outlined),
                        label: data.isBackingUp
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Backup Data'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (data.isExporting || data.isBackingUp)
                            ? null
                            : () => _exportExcel(data),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: Text(
                          data.isExporting ? 'Exporting...' : 'Export Excel',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (data.isExporting || data.isBackingUp)
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
              if (data.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
              Expanded(
                child: reports.isEmpty
                    ? Center(child: Text(context.tr('noReportData')))
                    : filteredReports.isEmpty
                        ? const Center(
                            child: Text('No person found for this name'),
                          )
                        : RefreshIndicator(
                            onRefresh: data.loadReport,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: filteredReports.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = filteredReports[index];
                                return _ReportTile(item: item);
                              },
                            ),
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

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    ).format(value);
  }

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
            const _SectionHeader(
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
            const _SectionHeader(
              icon: Icons.currency_rupee,
              title: 'Earnings',
            ),
            const SizedBox(height: 8),
            _summaryRow(
              context,
              label: context.tr('basePay'),
              value: _formatCurrency(item.totalEarned),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            _summaryRow(
              context,
              label: context.tr('overtimePay'),
              value: _formatCurrency(item.overtimePay),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
            const Divider(height: 24),
            const _SectionHeader(
              icon: Icons.remove_circle_outline,
              title: 'Deductions',
            ),
            const SizedBox(height: 8),
            _summaryRow(
              context,
              label: context.tr('advance'),
              value: _formatCurrency(item.advanceAmount),
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
                    _formatCurrency(item.finalPay),
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
