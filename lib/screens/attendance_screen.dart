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

        // Apply search filter (only relevant in marking mode)
        final filteredLabours = _searchQuery.isEmpty
            ? allLabours
            : allLabours.where((l) =>
                l.name.toLowerCase().contains(_searchQuery) ||
                l.phone.contains(_searchQuery)).toList();

        // Pending = NOT yet marked today across ANY site
        final pendingList = filteredLabours.where((l) => !attendanceByLabour.containsKey(l.id)).toList();
        final markedList  = filteredLabours.where((l) => attendanceByLabour.containsKey(l.id)).toList();

        // Stats across all labours for today
        final presentCount = attendanceByLabour.values.where((v) => v == 'present').length;
        final absentCount  = attendanceByLabour.values.where((v) => v == 'absent').length;
        final halfDayCount = attendanceByLabour.values.where((v) => v == 'half').length;
        final totalMarked  = presentCount + absentCount + halfDayCount;
        final totalLabours = allLabours.length;

        // How many labours marked at each site today
        final markedBySite = <String, int>{};
        for (final entry in data.siteMap.entries) {
          if (attendanceByLabour.containsKey(entry.key) && entry.value.isNotEmpty) {
            markedBySite[entry.value] = (markedBySite[entry.value] ?? 0) + 1;
          }
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _buildDateBar(context, data),

              // ── SITE PICKER MODE (no site selected) ──────────────────────
              if (_selectedSiteId == null)
                Expanded(
                  child: _buildSitePickerBody(
                    sites: sites,
                    markedBySite: markedBySite,
                    totalMarkedToday: totalMarked,
                    isLoading: sitesData.isLoading,
                  ),
                )

              // ── MARKING MODE (site selected) ──────────────────────────────
              else ...[
                _buildStatsBar(presentCount, absentCount, halfDayCount, totalLabours, totalMarked),
                _buildActiveSiteHeader(sites, data),
                _buildSearchBar(),
                Expanded(
                  child: data.isLoading
                      ? const ShimmerList(count: 5, height: 110)
                      : data.labours.isEmpty
                          ? const EmptyState(
                              icon: Icons.fact_check_outlined,
                              title: 'No Labour Added',
                              subtitle: 'Add labours first to mark attendance.',
                            )
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: data.initialize,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  _buildTempLabourButton(data),
                                  const SizedBox(height: 8),

                                  // Pending labours — all not yet marked today
                                  if (pendingList.isEmpty && _searchQuery.isEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.presentSurface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.present.withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.check_circle_outline, color: AppColors.present, size: 20),
                                          SizedBox(width: 10),
                                          Text(
                                            'All labours marked for today!',
                                            style: TextStyle(color: AppColors.present, fontWeight: FontWeight.w600, fontSize: 14),
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
                                              'Available — ${pendingList.length}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                                            ),
                                            const Spacer(),
                                            const Text('Already marked → scroll down', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                          ],
                                        ),
                                      ),
                                    // All unassigned labours — siteId applied at mark time
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

                                  // Safety Net — already marked (any site)
                                  if (markedList.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _buildSafetyNetPanel(context, data, markedList, sites),
                                  ],
                                ],
                              ),
                            ),
                ),
              ],
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

  // ── Site Picker (fullscreen, shown when no site is selected) ────────────
  Widget _buildSitePickerBody({
    required List<SiteModel> sites,
    required Map<String, int> markedBySite,
    required int totalMarkedToday,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a Site',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                totalMarkedToday > 0
                    ? '$totalMarkedToday labour${totalMarkedToday == 1 ? '' : 's'} marked across all sites today'
                    : 'Choose which site to mark attendance for',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (sites.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.location_city_outlined,
              title: 'No Sites Added',
              subtitle: 'Ask your admin to create sites first.',
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: sites.length,
              itemBuilder: (_, i) {
                final site = sites[i];
                final count = markedBySite[site.id] ?? 0;
                return _SitePickerCard(
                  site: site,
                  markedCount: count,
                  onTap: () {
                    HapticUtils.light();
                    setState(() => _selectedSiteId = site.id);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Active Site Header (shown when a site IS selected) ──────────────────
  Widget _buildActiveSiteHeader(List<SiteModel> sites, AttendanceProvider data) {
    SiteModel? site;
    try { site = sites.firstWhere((s) => s.id == _selectedSiteId); } catch (_) {}

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticUtils.light();
                setState(() { _selectedSiteId = null; _searchController.clear(); });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.location_on_rounded, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                site?.name ?? _selectedSiteId ?? '',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticUtils.light();
                _showAllowanceSheet(data, sites);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Allowances', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllowanceSheet(AttendanceProvider data, List<SiteModel> sites) {
    if (_selectedSiteId == null) return;
    SiteModel? site;
    try { site = sites.firstWhere((s) => s.id == _selectedSiteId); } catch (_) {}

    final presentLabours = data.labours.where((l) {
      final status = data.attendanceMap[l.id];
      final labourSite = data.siteMap[l.id] ?? '';
      return (status == 'present' || status == 'half') && labourSite == _selectedSiteId;
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _PerLabourAllowanceSheet(
        siteId: _selectedSiteId!,
        siteName: site?.name ?? _selectedSiteId!,
        presentLabours: presentLabours,
        provider: data,
      ),
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

// Site picker grid card — shown on the fullscreen site selection view
class _SitePickerCard extends StatelessWidget {
  const _SitePickerCard({
    required this.site,
    required this.markedCount,
    required this.onTap,
  });

  final SiteModel site;
  final int markedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasMarked = markedCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasMarked
                ? AppColors.primary.withValues(alpha: 0.30)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
                ),
                const Spacer(),
                if (hasMarked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.presentSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$markedCount ✓',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.present),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              site.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              hasMarked ? '$markedCount marked today' : 'Tap to start marking',
              style: TextStyle(
                fontSize: 11,
                color: hasMarked ? AppColors.present : AppColors.textTertiary,
                fontWeight: hasMarked ? FontWeight.w600 : FontWeight.w400,
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

// ─────────────────────────────────────────────────────────────────────────────
// _PerLabourAllowanceSheet — per-labour daily allowance setter with tabs
// ─────────────────────────────────────────────────────────────────────────────

class _PerLabourAllowanceSheet extends StatefulWidget {
  const _PerLabourAllowanceSheet({
    required this.siteId,
    required this.siteName,
    required this.presentLabours,
    required this.provider,
  });

  final String siteId;
  final String siteName;
  final List<Labour> presentLabours;
  final AttendanceProvider provider;

  @override
  State<_PerLabourAllowanceSheet> createState() => _PerLabourAllowanceSheetState();
}

class _PerLabourAllowanceSheetState extends State<_PerLabourAllowanceSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Per-labour controllers: key = 'labourId_type' (type = petrol|lunch|breakfast|tea|advance)
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, bool> _enabled = {};
  final Set<String> _saving = {};
  final Set<String> _saved = {};

  static const _types = ['petrol', 'lunch', 'breakfast', 'tea'];
  static const _typeEmoji = {'petrol': '🚗', 'lunch': '🍽', 'breakfast': '🍳', 'tea': '☕'};
  static const _typeLabel = {'petrol': 'Petrol', 'lunch': 'Lunch', 'breakfast': 'Breakfast', 'tea': 'Tea'};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (final l in widget.presentLabours) {
      final petrol    = widget.provider.allowancePetrolMap[l.id]    ?? 0;
      final lunch     = widget.provider.allowanceLunchMap[l.id]     ?? 0;
      final breakfast = widget.provider.allowanceBreakfastMap[l.id] ?? 0;
      final tea       = widget.provider.allowanceTeaMap[l.id]       ?? 0;
      final advance   = widget.provider.advanceMap[l.id]            ?? 0;
      _ctrls['${l.id}_petrol']    = TextEditingController(text: petrol > 0 ? petrol.toStringAsFixed(0) : '');
      _ctrls['${l.id}_lunch']     = TextEditingController(text: lunch > 0 ? lunch.toStringAsFixed(0) : '');
      _ctrls['${l.id}_breakfast'] = TextEditingController(text: breakfast > 0 ? breakfast.toStringAsFixed(0) : '');
      _ctrls['${l.id}_tea']       = TextEditingController(text: tea > 0 ? tea.toStringAsFixed(0) : '');
      _ctrls['${l.id}_advance']   = TextEditingController(text: advance > 0 ? advance.toStringAsFixed(0) : '');
      _enabled['${l.id}_petrol']    = petrol > 0;
      _enabled['${l.id}_lunch']     = lunch > 0;
      _enabled['${l.id}_breakfast'] = breakfast > 0;
      _enabled['${l.id}_tea']       = tea > 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  double _val(String labourId, String type) =>
      double.tryParse(_ctrls['${labourId}_$type']?.text.trim() ?? '') ?? 0;

  bool _on(String labourId, String type) => _enabled['${labourId}_$type'] ?? false;

  double _totalForLabour(String labourId) =>
      _types.map((t) => _on(labourId, t) ? _val(labourId, t) : 0.0).fold(0, (a, b) => a + b);

  double get _grandTotal => widget.presentLabours
      .map((l) => _totalForLabour(l.id) - (_on(l.id, 'advance') ? 0 : 0))
      .fold(0, (a, b) => a + b);

  Future<void> _saveLabour(Labour l) async {
    setState(() { _saving.add(l.id); _saved.remove(l.id); });
    try {
      await widget.provider.updateSingleLabourAllowances(
        labourId:  l.id,
        petrol:    _on(l.id, 'petrol')    ? _val(l.id, 'petrol')    : 0,
        lunch:     _on(l.id, 'lunch')     ? _val(l.id, 'lunch')     : 0,
        breakfast: _on(l.id, 'breakfast') ? _val(l.id, 'breakfast') : 0,
        tea:       _on(l.id, 'tea')       ? _val(l.id, 'tea')       : 0,
        advance:   double.tryParse(_ctrls['${l.id}_advance']?.text.trim() ?? '') ?? 0,
      );
      if (mounted) setState(() { _saved.add(l.id); });
    } finally {
      if (mounted) setState(() => _saving.remove(l.id));
    }
  }

  Future<void> _saveAll() async {
    for (final l in widget.presentLabours) {
      await _saveLabour(l);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Allowances saved for ${widget.presentLabours.length} labour${widget.presentLabours.length == 1 ? '' : 's'} ✓'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _amountField(String labourId, String type, {bool isAdvance = false}) {
    final key = '${labourId}_$type';
    final enabled = isAdvance ? true : (_enabled[key] ?? false);
    final ctrl = _ctrls[key];
    if (ctrl == null) return const SizedBox.shrink();
    return SizedBox(
      width: 80,
      child: TextField(
        controller: ctrl,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: enabled ? AppColors.textPrimary : AppColors.textTertiary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          prefixText: '₹',
          hintText: '0',
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isAdvance ? Colors.red.shade300 : AppColors.primary.withValues(alpha: 0.4))),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      ),
    );
  }

  Widget _buildLabourCard(Labour l) {
    final isSavingThis = _saving.contains(l.id);
    final isSavedThis  = _saved.contains(l.id);
    final total = _totalForLabour(l.id);
    final advance = double.tryParse(_ctrls['${l.id}_advance']?.text.trim() ?? '') ?? 0;
    final initial = l.name.isNotEmpty ? l.name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSavedThis ? AppColors.present.withValues(alpha: 0.4) : AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                  if (total > 0)
                    Text('Total: ₹${total.toStringAsFixed(0)}${advance > 0 ? ' · Advance: ₹${advance.toStringAsFixed(0)}' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
              if (isSavedThis)
                const Icon(Icons.check_circle_rounded, color: AppColors.present, size: 18)
              else
                GestureDetector(
                  onTap: isSavingThis ? null : () => _saveLabour(l),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSavingThis ? Colors.grey.shade200 : AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isSavingThis
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Allowance type rows
          ..._types.map((type) {
            final key = '${l.id}_$type';
            final on = _enabled[key] ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Switch.adaptive(
                      value: on,
                      onChanged: (v) => setState(() => _enabled[key] = v),
                      activeColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(_typeEmoji[type]!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_typeLabel[type]!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? AppColors.textPrimary : AppColors.textSecondary))),
                  _amountField(l.id, type),
                ],
              ),
            );
          }),
          // Advance row
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const SizedBox(width: 40),
                const Icon(Icons.payments_outlined, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                const Expanded(child: Text('Advance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red))),
                _amountField(l.id, 'advance', isAdvance: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildByTypeTab() {
    if (widget.presentLabours.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No present labours at this site', style: TextStyle(color: AppColors.textSecondary)),
      ));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        ..._types.map((type) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Text('${_typeEmoji[type]!} ${_typeLabel[type]!}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: AppColors.border)),
              ]),
            ),
            ...widget.presentLabours.map((l) {
              final key = '${l.id}_$type';
              final on = _enabled[key] ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Switch.adaptive(
                        value: on,
                        onChanged: (v) => setState(() => _enabled[key] = v),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(l.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                      _amountField(l.id, type),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _grandTotal;
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Daily Allowances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      Text('${widget.siteName} · ${widget.presentLabours.length} labour${widget.presentLabours.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [Tab(text: 'By Labour'), Tab(text: 'By Type')],
              ),
            ),
            const SizedBox(height: 8),
            // Tab body
            Expanded(
              child: widget.presentLabours.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No present labours at this site', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          const SizedBox(height: 6),
                          const Text('Mark labours as present first, then set their allowances here.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12), textAlign: TextAlign.center),
                        ]),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // By Labour tab
                        ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: widget.presentLabours.length,
                          itemBuilder: (_, i) => _buildLabourCard(widget.presentLabours[i]),
                        ),
                        // By Type tab
                        _buildByTypeTab(),
                      ],
                    ),
            ),
            // Sticky bottom bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total (all labours)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('₹${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: widget.presentLabours.isEmpty ? null : _saveAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Save All ${widget.presentLabours.length} Labour${widget.presentLabours.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
}
