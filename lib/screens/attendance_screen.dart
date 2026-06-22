import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/date_utils.dart';
import '../core/utils/haptic_utils.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/labour_model.dart';
import '../models/site_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/sites_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loader.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _safetyNetExpanded = false;

  // Sites feature: null = All Sites
  String? _selectedSiteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().initialize();
      context.read<SitesProvider>().load();
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddTempLabourDialog(AttendanceProvider data) async {
    final nameCtrl = TextEditingController();
    final wageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Add Temp Labour', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Temp labours are marked present today only.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: _inputDecoration('Name', Icons.badge_outlined),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: wageCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: _inputDecoration('Daily Wage (₹)', Icons.currency_rupee_rounded),
                validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Enter valid wage' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await data.addTempLabour(
                name: nameCtrl.text.trim(),
                dailyWage: double.parse(wageCtrl.text.trim()),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${nameCtrl.text.trim()} added & marked present'),
                    backgroundColor: AppColors.present,
                  ),
                );
              }
            },
            child: const Text('Add & Mark Present'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AttendanceProvider, SitesProvider>(
      builder: (context, data, sitesData, _) {
        final attendanceByLabour = data.attendanceMap;
        final sites = sitesData.sites;

        // All labours are available every morning — no permanent site assignment.
        // Site is only recorded on the attendance record for that day.
        final List<Labour> allLabours = data.labours;

        // Apply search
        final filteredLabours = _searchQuery.isEmpty
            ? allLabours
            : allLabours.where((l) =>
                l.name.toLowerCase().contains(_searchQuery) ||
                l.phone.contains(_searchQuery)).toList();

        final pendingList = filteredLabours.where((l) => !attendanceByLabour.containsKey(l.id)).toList();
        final markedList  = filteredLabours.where((l) => attendanceByLabour.containsKey(l.id)).toList();

        // Stats across all labours
        final presentCount = attendanceByLabour.values.where((v) => v == 'present').length;
        final absentCount  = attendanceByLabour.values.where((v) => v == 'absent').length;
        final halfDayCount = attendanceByLabour.values.where((v) => v == 'half').length;
        final totalMarked  = presentCount + absentCount + halfDayCount;
        final totalLabours = allLabours.length;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _buildDateBar(context, data),
              _buildStatsBar(presentCount, absentCount, halfDayCount, totalLabours, totalMarked),

              // ── SITES SELECTOR ──────────────────────────────────────────
              if (sites.isNotEmpty)
                _buildSiteSelector(sites, attendanceByLabour, data.siteMap),

              _buildSearchBar(),
              _buildSummaryRow(presentCount, absentCount, halfDayCount),
              Expanded(
                child: Stack(
                  children: [
                    if (data.isLoading)
                      const ShimmerList(count: 5, height: 110)
                    else if (data.labours.isEmpty)
                      const EmptyState(
                        icon: Icons.fact_check_outlined,
                        title: 'No Labour Added',
                        subtitle: 'Add labours first to mark attendance.',
                      )
                    else
                      RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: data.initialize,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            // Add Temp Labour button
                            _buildTempLabourButton(data),
                            const SizedBox(height: 8),

                            // Pending (unmarked) labours
                            if (pendingList.isEmpty && _searchQuery.isEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.presentSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.present.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: AppColors.present, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      _selectedSiteId != null
                                          ? 'All labours in this site marked!'
                                          : 'All labours marked for today!',
                                      style: const TextStyle(color: AppColors.present, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              if (_searchQuery.isEmpty && pendingList.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Pending — ${pendingList.length}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                                      ),
                                      const Spacer(),
                                      const Text('Already marked → scroll down', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                    ],
                                  ),
                                ),

                              // All pending labours shown — site is applied at mark time
                              // via the site card selected above.
                              ...pendingList.map((labour) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AttendanceCard(
                                  labour: labour,
                                  status: attendanceByLabour[labour.id],
                                  remark: data.remarkMap[labour.id] ?? '',
                                  data: data,
                                  siteId: _selectedSiteId ?? '',
                                ),
                              )),
                            ],

                            // Temp labours for today
                            if (data.tempLabours.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildSectionHeader('Today\'s Temp Workers', Icons.person_outline, Colors.purple),
                              const SizedBox(height: 8),
                              ...data.tempLabours.map((labour) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AttendanceCard(
                                  labour: labour,
                                  status: attendanceByLabour[labour.id],
                                  remark: data.remarkMap[labour.id] ?? '',
                                  data: data,
                                  isTemp: true,
                                ),
                              )),
                            ],

                            // Safety Net Panel
                            if (markedList.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildSafetyNetPanel(context, data, markedList, sites),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _siteName(List<SiteModel> sites, String siteId) {
    if (siteId.isEmpty) return '';
    try {
      return sites.firstWhere((s) => s.id == siteId).name;
    } catch (_) {
      return '';
    }
  }

  Widget _buildSiteSelector(List<SiteModel> sites, Map<String, String> attendanceByLabour, Map<String, String> siteMap) {
    // Count how many labours were marked at each site today
    final markedBySite = <String, int>{};
    for (final entry in siteMap.entries) {
      if (attendanceByLabour.containsKey(entry.key) && entry.value.isNotEmpty) {
        markedBySite[entry.value] = (markedBySite[entry.value] ?? 0) + 1;
      }
    }

    SiteModel? selectedSite;
    if (_selectedSiteId != null) {
      try { selectedSite = sites.firstWhere((s) => s.id == _selectedSiteId); } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.apartment_rounded, size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 5),
              Text(
                'Sites — ${sites.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5),
              ),
              const Spacer(),
              if (_selectedSiteId != null)
                GestureDetector(
                  onTap: () { HapticUtils.light(); setState(() => _selectedSiteId = null); },
                  child: const Text('Show All', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              _SiteCard(
                label: 'All Sites',
                icon: Icons.grid_view_rounded,
                count: attendanceByLabour.length,
                countLabel: '${attendanceByLabour.length} marked',
                selected: _selectedSiteId == null,
                onTap: () { HapticUtils.light(); setState(() => _selectedSiteId = null); },
              ),
              ...sites.map((site) {
                final markedHere = markedBySite[site.id] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _SiteCard(
                    label: site.name,
                    icon: Icons.location_on_rounded,
                    count: markedHere,
                    countLabel: markedHere > 0 ? '$markedHere marked' : 'Tap to mark',
                    selected: _selectedSiteId == site.id,
                    onTap: () { HapticUtils.light(); setState(() => _selectedSiteId = site.id); },
                  ),
                );
              }),
            ],
          ),
        ),
        // Active site banner
        if (selectedSite != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        children: [
                          const TextSpan(text: 'Marking for '),
                          TextSpan(
                            text: selectedSite.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () { HapticUtils.light(); setState(() => _selectedSiteId = null); },
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTempLabourButton(AttendanceProvider data) {
    return GestureDetector(
      onTap: () { HapticUtils.light(); _showAddTempLabourDialog(data); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.purple.shade700),
            const SizedBox(width: 8),
            Text('+ Add Temp Labour', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
        Expanded(child: Container(margin: const EdgeInsets.only(left: 10), height: 1, color: color.withValues(alpha: 0.2))),
      ],
    );
  }

  Widget _buildSafetyNetPanel(BuildContext context, AttendanceProvider data, List<Labour> markedList, List<SiteModel> sites) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () { HapticUtils.light(); setState(() => _safetyNetExpanded = !_safetyNetExpanded); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(Icons.security_rounded, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Already Marked Today — ${markedList.length}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.amber.shade900)),
                        Text('Tap to review & fix before day locks',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                      ],
                    ),
                  ),
                  Icon(_safetyNetExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.amber.shade800),
                ],
              ),
            ),
          ),
          if (_safetyNetExpanded) ...[
            const SizedBox(height: 4),
            ...markedList.map((labour) {
              final status = data.attendanceMap[labour.id] ?? 'absent';
              final remark = data.remarkMap[labour.id] ?? '';
              final markedSiteId = data.siteMap[labour.id] ?? '';
              final siteN = _siteName(sites, markedSiteId);
              return _SafetyNetCard(
                labour: labour,
                status: status,
                siteId: markedSiteId,
                siteName: siteN,
                remark: remark,
                data: data,
              );
            }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search labour by name or phone...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                  onPressed: () { _searchController.clear(); HapticUtils.light(); },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildStatsBar(int present, int absent, int half, int total, int marked) {
    if (total == 0) return const SizedBox.shrink();
    final unmarked = total - marked;
    final presentPct  = total > 0 ? present / total : 0.0;
    final halfPct     = total > 0 ? half / total : 0.0;
    final absentPct   = total > 0 ? absent / total : 0.0;
    final unmarkedPct = total > 0 ? unmarked / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$marked of $total marked',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${total > 0 ? (marked / total * 100).round() : 0}% complete',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (present > 0) Flexible(flex: (presentPct * 1000).round(), child: Container(height: 6, color: AppColors.present)),
                if (half > 0) Flexible(flex: (halfPct * 1000).round(), child: Container(height: 6, color: AppColors.halfDay)),
                if (absent > 0) Flexible(flex: (absentPct * 1000).round(), child: Container(height: 6, color: AppColors.absent)),
                if (unmarked > 0) Flexible(flex: (unmarkedPct * 1000).round(), child: Container(height: 6, color: AppColors.border)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBar(BuildContext context, AttendanceProvider data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(AppDateUtils.toDisplay(data.selectedDate), style: AppTextStyles.headingMedium)),
          GestureDetector(
            onTap: () async {
              HapticUtils.light();
              final picked = await showDatePicker(
                context: context,
                initialDate: data.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
                  child: child!,
                ),
              );
              if (picked != null) data.changeDate(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Text('Change', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(int present, int absent, int half) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(child: _SummaryChip(label: 'Present', count: present, color: AppColors.present, bg: AppColors.presentSurface)),
          const SizedBox(width: 8),
          Expanded(child: _SummaryChip(label: 'Absent', count: absent, color: AppColors.absent, bg: AppColors.absentSurface)),
          const SizedBox(width: 8),
          Expanded(child: _SummaryChip(label: 'Half Day', count: half, color: AppColors.halfDay, bg: AppColors.halfSurface)),
        ],
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.label,
    required this.icon,
    required this.count,
    required this.countLabel,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final int count;
  final String countLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActivity = count > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 118,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : hasActivity
                    ? AppColors.present.withValues(alpha: 0.45)
                    : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: selected ? Colors.white : AppColors.primary),
                ),
                const Spacer(),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : AppColors.present.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.present,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              countLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: hasActivity ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? Colors.white.withValues(alpha: 0.75)
                    : hasActivity
                        ? AppColors.present
                        : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.count, required this.color, required this.bg});
  final String label;
  final int count;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SafetyNetCard extends StatelessWidget {
  const _SafetyNetCard({
    required this.labour,
    required this.status,
    required this.siteId,
    required this.siteName,
    required this.remark,
    required this.data,
  });
  final Labour labour;
  final String status;
  final String siteId;
  final String siteName;
  final String remark;
  final AttendanceProvider data;

  @override
  Widget build(BuildContext context) {
    final color = status == 'present' ? AppColors.present : status == 'absent' ? AppColors.absent : AppColors.halfDay;
    final label = status == 'present' ? 'Present' : status == 'absent' ? 'Absent' : 'Half Day';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                labour.name.isNotEmpty ? labour.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labour.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                    ),
                    if (siteName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
                        child: Text(siteName, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (remark.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('"$remark"',
                            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontStyle: FontStyle.italic),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniStatusBtn('P', status == 'present', AppColors.present, () => data.markAttendance(labour.id, 'present')),
              const SizedBox(width: 4),
              _miniStatusBtn('A', status == 'absent', AppColors.absent, () => data.markAttendance(labour.id, 'absent')),
              const SizedBox(width: 4),
              _miniStatusBtn('H', status == 'half', AppColors.halfDay, () => data.markAttendance(labour.id, 'half')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatusBtn(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : color)),
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatefulWidget {
  const _AttendanceCard({
    required this.labour,
    required this.status,
    required this.remark,
    required this.data,
    this.isTemp = false,
    this.siteId = '',
  });

  final Labour labour;
  final String? status;
  final String remark;
  final AttendanceProvider data;
  final bool isTemp;
  final String siteId;

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<_AttendanceCard> {
  late final TextEditingController _remarkCtrl;
  Timer? _remarkDebounce;
  bool _remarkFocused = false;

  @override
  void initState() {
    super.initState();
    _remarkCtrl = TextEditingController(text: widget.remark);
  }

  @override
  void didUpdateWidget(_AttendanceCard old) {
    super.didUpdateWidget(old);
    if (old.remark != widget.remark && !_remarkFocused) {
      _remarkCtrl.text = widget.remark;
    }
  }

  @override
  void dispose() {
    _remarkDebounce?.cancel();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _scheduleRemarkSave(String value) {
    _remarkDebounce?.cancel();
    _remarkDebounce = Timer(const Duration(milliseconds: 700), () {
      widget.data.setRemark(widget.labour.id, value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final labour = widget.labour;
    final status = widget.status;
    final initial = labour.name.isNotEmpty ? labour.name[0].toUpperCase() : '?';
    final isMarked = status != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isTemp
              ? Colors.purple.shade200
              : isMarked ? AppColors.border.withValues(alpha: 0.5) : AppColors.border,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isTemp
                        ? [Colors.purple.shade400, Colors.purple.shade300]
                        : [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(labour.name, style: AppTextStyles.headingMedium, overflow: TextOverflow.ellipsis)),
                        if (widget.isTemp)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(6)),
                            child: Text('TEMP', style: TextStyle(fontSize: 9, color: Colors.purple.shade700, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${labour.phone.isNotEmpty ? labour.phone : 'No phone'}  •  ₹${labour.dailyWage.toStringAsFixed(0)}/day',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (status != null) _statusIndicator(status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _statusBtn('P', 'Present', status == 'present', AppColors.present, () {
                HapticUtils.select();
                widget.data.markAttendance(labour.id, 'present', remark: _remarkCtrl.text.trim(), siteId: widget.siteId);
              })),
              const SizedBox(width: 8),
              Expanded(child: _statusBtn('A', 'Absent', status == 'absent', AppColors.absent, () {
                HapticUtils.select();
                widget.data.markAttendance(labour.id, 'absent', remark: _remarkCtrl.text.trim(), siteId: widget.siteId);
              })),
              const SizedBox(width: 8),
              Expanded(child: _statusBtn('H', 'Half', status == 'half', AppColors.halfDay, () {
                HapticUtils.select();
                widget.data.markAttendance(labour.id, 'half', remark: _remarkCtrl.text.trim(), siteId: widget.siteId);
              })),
            ],
          ),
          // Remark field
          const SizedBox(height: 10),
          Focus(
            onFocusChange: (f) => setState(() => _remarkFocused = f),
            child: TextField(
              controller: _remarkCtrl,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              onChanged: _scheduleRemarkSave,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Remark (e.g. tile fixing 2nd floor)',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.textTertiary),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.0)),
              ),
            ),
          ),
          if (status == 'present' || status == 'half') ...[
            const SizedBox(height: 10),
            _OvertimeField(
              key: ValueKey('ot_${labour.id}_${widget.data.selectedDateStr}'),
              labourId: labour.id,
              initial: widget.data.overtimeMap[labour.id] ?? 0,
              overtimeRate: labour.overtimeWagePerHour,
              onChanged: (h) => widget.data.setOvertime(labour.id, h),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIndicator(String s) {
    final color = s == 'present' ? AppColors.present : s == 'absent' ? AppColors.absent : AppColors.halfDay;
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  Widget _statusBtn(String short, String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.2), width: selected ? 0 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Center(
          child: Text(
            selected ? label : short,
            style: TextStyle(fontSize: selected ? 12 : 14, fontWeight: FontWeight.w700, color: selected ? Colors.white : color),
          ),
        ),
      ),
    );
  }
}

class _OvertimeField extends StatefulWidget {
  const _OvertimeField({
    super.key,
    required this.labourId,
    required this.initial,
    required this.overtimeRate,
    required this.onChanged,
  });

  final String labourId;
  final double initial;
  final double overtimeRate;
  final ValueChanged<double> onChanged;

  @override
  State<_OvertimeField> createState() => _OvertimeFieldState();
}

class _OvertimeFieldState extends State<_OvertimeField> {
  late final TextEditingController _controller;
  Timer? _debounce;
  double _lastSent = 0;

  @override
  void initState() {
    super.initState();
    _lastSent = widget.initial;
    _controller = TextEditingController(text: widget.initial > 0 ? _format(widget.initial) : '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  void _scheduleSend(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final parsed = double.tryParse(raw.trim()) ?? 0;
      final clamped = parsed.isFinite && parsed >= 0 ? parsed : 0.0;
      if ((clamped - _lastSent).abs() < 0.0001) return;
      _lastSent = clamped;
      widget.onChanged(clamped);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = double.tryParse(_controller.text.trim()) ?? 0;
    final pay = hours * widget.overtimeRate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.halfSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.halfDay.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_outlined, size: 15, color: AppColors.halfDay),
          const SizedBox(width: 6),
          const Text('OT hrs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.halfDay)),
          const SizedBox(width: 10),
          SizedBox(
            width: 64, height: 34,
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,1})?'))],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              onChanged: _scheduleSend,
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.halfDay)),
              ),
            ),
          ),
          if (widget.overtimeRate > 0 && hours > 0) ...[
            const SizedBox(width: 10),
            Text('= ₹${pay.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.halfDay)),
          ],
        ],
      ),
    );
  }
}
