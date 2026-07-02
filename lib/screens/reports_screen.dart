import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/labour_report_summary.dart';
import '../providers/report_provider.dart';

// ─── Colour constants ────────────────────────────────────────────────────────
const _kGreen  = Color(0xFF22C55E);
const _kGold   = Color(0xFFD4A437);
const _kRed    = Color(0xFFEF4444);
const _kOrange = Color(0xFFF97316);
const _kBlue   = Color(0xFF3B82F6);
const _kBg     = Color(0xFFF8F7F3);
const _kCard   = Color(0xFFFFFFFF);

// ─── Sort options ─────────────────────────────────────────────────────────────
enum _SortBy { none, highestSalary, lowestSalary, highestOT, mostPresent, mostAbsent, az }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _refreshTimer;
  _SortBy _sortBy = _SortBy.none;
  String _filterChip = 'All';

  static const _chips = ['All', 'Present', 'Absent', 'Half Day', 'High OT', 'High Advance'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadReport();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      context.read<ReportProvider>().loadReport();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _backupData(ReportProvider data) async {
    if (data.isBackingUp || data.isExporting) return;
    await data.backupData();
    if (!mounted) return;
    if (data.error != null) { _showMessage(data.error!); return; }
    _showMessage('Backup completed successfully');
  }

  Future<void> _exportExcel(ReportProvider data) async {
    if (data.isExporting || data.isBackingUp) return;
    await data.exportExcel();
    if (!mounted) return;
    if (data.error != null) { _showMessage(data.error!); return; }
    if (data.exportedFilePath != null) _showMessage('File saved: ${data.exportedFilePath}');
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  List<LabourReportSummary> _applyFilters(List<LabourReportSummary> reports) {
    var list = reports.where((item) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isNotEmpty && !item.labourName.toLowerCase().contains(q)) return false;
      switch (_filterChip) {
        case 'Present':   return item.presentDays > 0;
        case 'Absent':    return item.absentDays > 0;
        case 'Half Day':  return item.halfDays > 0;
        case 'High OT':   return item.extraHours > 0;
        case 'High Advance': return item.advanceAmount > 0;
        default:          return true;
      }
    }).toList();

    switch (_sortBy) {
      case _SortBy.highestSalary: list.sort((a, b) => b.finalPay.compareTo(a.finalPay));
      case _SortBy.lowestSalary:  list.sort((a, b) => a.finalPay.compareTo(b.finalPay));
      case _SortBy.highestOT:     list.sort((a, b) => b.extraHours.compareTo(a.extraHours));
      case _SortBy.mostPresent:   list.sort((a, b) => b.presentDays.compareTo(a.presentDays));
      case _SortBy.mostAbsent:    list.sort((a, b) => b.absentDays.compareTo(a.absentDays));
      case _SortBy.az:            list.sort((a, b) => a.labourName.compareTo(b.labourName));
      case _SortBy.none: break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, data, _) {
        final filtered = _applyFilters(data.summaries);

        // Aggregate totals for sticky footer & summary card
        final totalWorkers   = data.summaries.length;
        final totalPayroll   = data.summaries.fold<double>(0, (s, r) => s + r.totalEarned + r.overtimePay);
        final totalPresent   = data.summaries.fold<int>(0, (s, r) => s + r.presentDays);
        final totalAbsent    = data.summaries.fold<int>(0, (s, r) => s + r.absentDays);
        final totalAdvance   = data.summaries.fold<double>(0, (s, r) => s + r.advanceAmount);
        final netPayroll     = data.summaries.fold<double>(0, (s, r) => s + r.finalPay);
        final avgWage        = totalWorkers > 0 ? (data.summaries.fold<double>(0, (s, r) => s + r.totalEarned) / totalWorkers) : 0.0;
        final totalOT        = data.summaries.fold<double>(0, (s, r) => s + r.extraHours);

        return Scaffold(
          backgroundColor: _kBg,
          body: Column(
            children: [
              // ── Top Action Bar ───────────────────────────────────────
              _TopActionBar(
                data: data,
                onBackup: () => _backupData(data),
                onExport: () => _exportExcel(data),
              ),
              // ── Search + Filter ──────────────────────────────────────
              _SearchFilterBar(
                controller: _searchController,
                query: _searchQuery,
                filterChip: _filterChip,
                sortBy: _sortBy,
                chips: _chips,
                onQueryChanged: (v) => setState(() => _searchQuery = v),
                onChipChanged: (v) => setState(() => _filterChip = v),
                onSortChanged: (v) => setState(() => _sortBy = v),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
              // ── Summary Card ─────────────────────────────────────────
              if (data.summaries.isNotEmpty)
                _SummaryCard(
                  totalWorkers: totalWorkers,
                  totalPayroll: totalPayroll,
                  totalPresent: totalPresent,
                  totalAbsent: totalAbsent,
                  avgWage: avgWage,
                  totalOT: totalOT,
                  totalAdvance: totalAdvance,
                  netPayroll: netPayroll,
                ),
              // ── List ─────────────────────────────────────────────────
              Expanded(child: _buildBody(data, filtered)),
            ],
          ),
          // ── Sticky Footer ─────────────────────────────────────────
          bottomNavigationBar: data.summaries.isEmpty
              ? null
              : _StickyFooter(
                  workers: filtered.length,
                  payroll: filtered.fold<double>(0, (s, r) => s + r.totalEarned + r.overtimePay),
                  netPay: filtered.fold<double>(0, (s, r) => s + r.finalPay),
                  presentPct: totalWorkers > 0
                      ? (totalPresent / (totalWorkers * 26) * 100).clamp(0, 100)
                      : 0,
                ),
        );
      },
    );
  }

  Widget _buildBody(ReportProvider data, List<LabourReportSummary> filtered) {
    if (data.isLoading) return _SkeletonList();

    if (data.summaries.isEmpty) {
      return _EmptyState(onRefresh: data.loadReport);
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text('No results for "$_searchQuery"',
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kGreen,
      onRefresh: data.loadReport,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
        itemCount: filtered.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CompactReportCard(
            item: filtered[index],
            isHighlighted: _searchQuery.isNotEmpty &&
                filtered[index].labourName.toLowerCase().contains(_searchQuery.toLowerCase()),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Action Bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopActionBar extends StatelessWidget {
  const _TopActionBar({required this.data, required this.onBackup, required this.onExport});
  final ReportProvider data;
  final VoidCallback onBackup;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.backup_rounded,
              label: data.isBackingUp ? 'Backing up…' : 'Backup Data',
              loading: data.isBackingUp,
              onTap: (data.isBackingUp || data.isExporting) ? null : onBackup,
              color: _kBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionBtn(
              icon: Icons.table_chart_rounded,
              label: data.isExporting ? 'Exporting…' : 'Export Excel',
              loading: data.isExporting,
              onTap: (data.isExporting || data.isBackingUp) ? null : onExport,
              color: _kGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.loading,
      required this.onTap, required this.color});
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + Filter Bar
// ─────────────────────────────────────────────────────────────────────────────
class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.controller, required this.query, required this.filterChip,
    required this.sortBy, required this.chips, required this.onQueryChanged,
    required this.onChipChanged, required this.onSortChanged, required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final String filterChip;
  final _SortBy sortBy;
  final List<String> chips;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onChipChanged;
  final ValueChanged<_SortBy> onSortChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search worker name…',
                hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: query.isEmpty
                    ? null
                    : GestureDetector(
                        onTap: onClear,
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: onQueryChanged,
            ),
          ),
        ),
        // Filter chips + sort button
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              ...chips.map((chip) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FilterPill(
                  label: chip,
                  selected: filterChip == chip,
                  onTap: () => onChipChanged(chip),
                ),
              )),
              _SortPill(current: sortBy, onChanged: onSortChanged),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kGreen : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kGreen : const Color(0xFFE2E8F0),
          ),
          boxShadow: selected
              ? [BoxShadow(color: _kGreen.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({required this.current, required this.onChanged});
  final _SortBy current;
  final ValueChanged<_SortBy> onChanged;

  String get _label {
    switch (current) {
      case _SortBy.highestSalary: return 'High Salary ↓';
      case _SortBy.lowestSalary:  return 'Low Salary ↑';
      case _SortBy.highestOT:     return 'High OT ↓';
      case _SortBy.mostPresent:   return 'Most Present';
      case _SortBy.mostAbsent:    return 'Most Absent';
      case _SortBy.az:            return 'A → Z';
      default:                    return 'Sort';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = current != _SortBy.none;
    return GestureDetector(
      onTap: () => _showSortSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _kGold.withValues(alpha: 0.12) : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _kGold : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 14,
                color: isActive ? _kGold : const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(_label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? _kGold : const Color(0xFF475569),
                )),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort Workers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
            ...[
              ('Default',          _SortBy.none),
              ('Highest Salary',   _SortBy.highestSalary),
              ('Lowest Salary',    _SortBy.lowestSalary),
              ('Highest Overtime', _SortBy.highestOT),
              ('Most Present',     _SortBy.mostPresent),
              ('Most Absent',      _SortBy.mostAbsent),
              ('A → Z',           _SortBy.az),
            ].map(((String label, _SortBy val) item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                current == item.$2 ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: current == item.$2 ? _kGreen : const Color(0xFFCBD5E1),
                size: 20,
              ),
              title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () { onChanged(item.$2); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Card (collapsed, one row each side)
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalWorkers, required this.totalPayroll, required this.totalPresent,
    required this.totalAbsent, required this.avgWage, required this.totalOT,
    required this.totalAdvance, required this.netPayroll,
  });

  final int totalWorkers;
  final double totalPayroll, avgWage, totalOT, totalAdvance, netPayroll;
  final int totalPresent, totalAbsent;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'en_IN');
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight, Color(0xFF2A3348)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.35),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Payroll Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SumChip(label: 'Workers',   value: '$totalWorkers',              icon: Icons.groups_rounded,               color: AppColors.goldLight),
              _SumChip(label: 'Payroll',   value: '₹${fmt.format(totalPayroll)}', icon: Icons.account_balance_wallet_rounded, color: AppColors.present),
              _SumChip(label: 'Present',   value: '$totalPresent',              icon: Icons.check_circle_rounded,         color: AppColors.present),
              _SumChip(label: 'Absent',    value: '$totalAbsent',              icon: Icons.cancel_rounded,               color: AppColors.absent),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SumChip(label: 'Avg Wage',  value: '₹${fmt.format(avgWage)}',    icon: Icons.trending_up_rounded,          color: AppColors.gold),
              _SumChip(label: 'OT Hrs',   value: totalOT.toStringAsFixed(1),   icon: Icons.bolt_rounded,                 color: AppColors.gold),
              _SumChip(label: 'Advance',  value: '₹${fmt.format(totalAdvance)}',icon: Icons.arrow_upward_rounded,         color: AppColors.absent),
              _SumChip(label: 'Net Pay',  value: '₹${fmt.format(netPayroll)}',  icon: Icons.verified_rounded,             color: AppColors.present),
            ],
          ),
        ],
      ),
    );
  }
}

class _SumChip extends StatelessWidget {
  const _SumChip({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact Expandable Report Card (~140 px collapsed)
// ─────────────────────────────────────────────────────────────────────────────
class _CompactReportCard extends StatefulWidget {
  const _CompactReportCard({required this.item, this.isHighlighted = false});
  final LabourReportSummary item;
  final bool isHighlighted;

  @override
  State<_CompactReportCard> createState() => _CompactReportCardState();
}

class _CompactReportCardState extends State<_CompactReportCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;
  late Animation<double> _arrowAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _arrowAnim  = Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _animCtrl.forward() : _animCtrl.reverse();
  }

  String _fmt(double v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

  double get _attendancePct {
    final total = widget.item.presentDays + widget.item.halfDays + widget.item.absentDays;
    if (total == 0) return 0;
    return ((widget.item.presentDays + widget.item.halfDays * 0.5) / total * 100).clamp(0, 100);
  }

  Color get _avatarRingColor {
    final p = _attendancePct;
    if (p >= 90) return _kGreen;
    if (p >= 70) return _kOrange;
    return _kRed;
  }

  Color get _salaryColor {
    final pct = _attendancePct;
    if (pct >= 85) return _kGreen;
    if (pct >= 60) return _kGold;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final initials = item.labourName.trim().isNotEmpty
        ? item.labourName.trim()[0].toUpperCase()
        : '?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isHighlighted
              ? _kGreen.withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: widget.isHighlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isHighlighted
                ? _kGreen.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: widget.isHighlighted ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Collapsed Row ──────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar with attendance ring
                  _AvatarRing(
                    initials: initials,
                    pct: _attendancePct,
                    ringColor: _avatarRingColor,
                  ),
                  const SizedBox(width: 12),
                  // Name + role + stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.labourName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.role.isNotEmpty ? item.role : 'Labour',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 7),
                        // Status pills row
                        Wrap(
                          spacing: 5,
                          children: [
                            _MiniPill(label: 'P ${item.presentDays}', color: _kGreen),
                            _MiniPill(label: 'H ${item.halfDays}', color: _kOrange),
                            _MiniPill(label: 'A ${item.absentDays}', color: _kRed),
                            if (item.extraHours > 0)
                              _MiniPill(label: 'OT ${item.extraHours.toStringAsFixed(1)}h', color: _kBlue),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Net salary + arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmt(item.finalPay),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: _salaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RotationTransition(
                        turns: _arrowAnim,
                        child: const Icon(Icons.expand_more_rounded,
                            size: 20, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded Section ───────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: _ExpandedDetails(item: item, fmt: _fmt),
          ),
        ],
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.initials, required this.pct, required this.ringColor});
  final String initials;
  final double pct;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct / 100,
            strokeWidth: 3,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(ringColor),
            strokeCap: StrokeCap.round,
          ),
          CircleAvatar(
            radius: 19,
            backgroundColor: ringColor.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: TextStyle(
                color: ringColor,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expanded Detail Section
// ─────────────────────────────────────────────────────────────────────────────
class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({required this.item, required this.fmt});
  final LabourReportSummary item;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Attendance section
                _DetailSection(
                  title: 'Attendance',
                  icon: Icons.fact_check_rounded,
                  rows: [
                    _DetailRow('Present Days', '${item.presentDays} days', const Color(0xFF16A34A)),
                    _DetailRow('Half Days',    '${item.halfDays} days',    _kOrange),
                    _DetailRow('Absent Days',  '${item.absentDays} days',  _kRed),
                    _DetailRow('Effective Days', item.effectiveWorkdays.toStringAsFixed(1), const Color(0xFF0F172A)),
                  ],
                ),
                const SizedBox(height: 12),
                // Earnings section
                _DetailSection(
                  title: 'Earnings',
                  icon: Icons.currency_rupee_rounded,
                  rows: [
                    _DetailRow('Base Salary',  fmt(item.totalEarned),  _kGreen),
                    _DetailRow('Overtime',      fmt(item.overtimePay),  _kBlue),
                  ],
                ),
                const SizedBox(height: 12),
                // Deductions section
                if (item.advanceAmount > 0)
                  _DetailSection(
                    title: 'Deductions',
                    icon: Icons.remove_circle_outline_rounded,
                    rows: [
                      _DetailRow('Advance', fmt(item.advanceAmount), _kRed),
                    ],
                  ),
                if (item.advanceAmount > 0) const SizedBox(height: 12),
                // Net Pay highlight
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Net Payable',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
                      Text(fmt(item.finalPay),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // OT row if present
                if (item.extraHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kGold.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, size: 16, color: _kGold),
                        const SizedBox(width: 8),
                        Text('Overtime: ${item.extraHours.toStringAsFixed(1)} hrs',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E))),
                        const Spacer(),
                        Text(fmt(item.overtimePay),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF92400E))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.icon, required this.rows});
  final String title;
  final IconData icon;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: _kGreen),
            const SizedBox(width: 6),
            Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B), letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 6),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(child: Text(r.label,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
              Text(r.value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: r.color)),
            ],
          ),
        )),
      ],
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value, this.color);
  final String label, value;
  final Color color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Footer
// ─────────────────────────────────────────────────────────────────────────────
class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.workers, required this.payroll,
    required this.netPay, required this.presentPct,
  });
  final int workers;
  final double payroll, netPay, presentPct;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact(locale: 'en_IN');
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _FooterStat(label: 'Workers',   value: '$workers',           icon: Icons.groups_rounded,    color: _kBlue),
          _FooterStat(label: 'Payroll',   value: '₹${fmt.format(payroll)}', icon: Icons.payments_rounded,  color: _kGreen),
          _FooterStat(label: 'Net Pay',   value: '₹${fmt.format(netPay)}',  icon: Icons.verified_rounded,  color: _kGold),
          _FooterStat(label: 'Present %', value: '${presentPct.toStringAsFixed(0)}%', icon: Icons.show_chart_rounded, color: _kGreen),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton Shimmer List
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonList extends StatefulWidget {
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            height: 90,
            decoration: BoxDecoration(
              color: Color.lerp(const Color(0xFFF1F5F9), const Color(0xFFE2E8F0), _anim.value),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFCBD5E1), _anim.value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 12, width: 140,
                          decoration: BoxDecoration(
                            color: Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFCBD5E1), _anim.value),
                            borderRadius: BorderRadius.circular(6),
                          )),
                      const SizedBox(height: 8),
                      Container(height: 10, width: 90,
                          decoration: BoxDecoration(
                            color: Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFCBD5E1), _anim.value),
                            borderRadius: BorderRadius.circular(6),
                          )),
                    ],
                  ),
                ),
                Container(
                  width: 60, height: 22,
                  decoration: BoxDecoration(
                    color: Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFCBD5E1), _anim.value),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.analytics_outlined, size: 44, color: _kGreen),
            ),
            const SizedBox(height: 18),
            const Text('No Reports Yet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Text(
              'Reports will appear here once attendance and payroll data is added.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Refresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
