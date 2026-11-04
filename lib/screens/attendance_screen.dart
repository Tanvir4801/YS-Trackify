import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/date_utils.dart';
import '../core/utils/haptic_utils.dart';
import '../core/utils/snackbar_utils.dart';
import '../core/theme/app_colors.dart';
import '../models/labour_model.dart';
import '../models/site_model.dart';
import '../models/temp_labour_entry.dart';
import '../providers/attendance_provider.dart';
import '../providers/sites_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/add_temp_labour_dialog.dart';
import '../widgets/loading_button.dart';
import '../widgets/attendance_site_row.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  final TextEditingController _siteSearchController = TextEditingController();
  String _siteSearchQuery = '';
  String _siteFilter = 'all'; // all, pending, completed
  
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
    _siteSearchController.addListener(() {
      setState(() => _siteSearchQuery = _siteSearchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _siteSearchController.dispose();
    super.dispose();
  }

  Future<void> _showAddTempLabourDialog(AttendanceProvider data) async {
    final sites = context.read<SitesProvider>().sites;
    String? selectedSite = _selectedSiteId;
    if (selectedSite == null || !sites.any((s) => s.id == selectedSite)) {
      selectedSite = sites.isNotEmpty ? sites.first.id : null;
    }
    if (selectedSite == null) {
      AppSnackBar.showError(context, 'Please create a site first');
      return;
    }
    
    final siteName = sites.firstWhere((s) => s.id == selectedSite).name;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AddTempLabourDialog(
        siteId: selectedSite!,
        siteName: siteName,
        onAdded: (labourId) {
           data.refreshLabours();
        }
      ),
    );
  }

  void _showTempPaymentSheet(AttendanceProvider data, TempLabourEntry entry) {
    double paidAmount = entry.paidAmount;
    String paymentMethod = entry.paymentMethod.isNotEmpty ? entry.paymentMethod : 'Cash';
    String paymentRemark = entry.paymentRemark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
            return Container(
              margin: EdgeInsets.only(bottom: keyboardHeight),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primaryColor(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.payment, color: AppColors.primaryColor(context), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Manage Payment',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimaryColor(context)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close, color: AppColors.textTertiaryColor(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Worker: ${entry.name}', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 13, fontWeight: FontWeight.w500)),
                  Text('Total Wage: ₹${entry.totalWage.toStringAsFixed(0)}', style: TextStyle(color: AppColors.primaryColor(context), fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 14),
                    decoration: _inputDecoration('Amount Paid (₹)', Icons.currency_rupee),
                    controller: TextEditingController(text: paidAmount > 0 ? paidAmount.toStringAsFixed(0) : '')..selection = TextSelection.collapsed(offset: paidAmount > 0 ? paidAmount.toStringAsFixed(0).length : 0),
                    onChanged: (v) => paidAmount = double.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    dropdownColor: AppColors.surfaceElevatedColor(context),
                    style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 14),
                    decoration: _inputDecoration('Payment Method', Icons.account_balance_wallet_outlined),
                    items: ['Cash', 'UPI', 'Bank Transfer', 'Other'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => paymentMethod = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 14),
                    decoration: _inputDecoration('Payment Remark (Optional)', Icons.notes),
                    controller: TextEditingController(text: paymentRemark)..selection = TextSelection.collapsed(offset: paymentRemark.length),
                    onChanged: (v) => paymentRemark = v,
                  ),
                  const SizedBox(height: 24),
                  LoadingButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      await data.updateTempLabourPayment(
                        entryId: entry.id,
                        paidAmount: paidAmount,
                        paymentMethod: paymentMethod,
                        paymentRemark: paymentRemark,
                      );
                      if (context.mounted) Navigator.pop(ctx);
                      HapticUtils.success();
                    },
                    child: const Text('Save Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiaryColor(context)),
      filled: true,
      fillColor: AppColors.cardColor(context),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor(context))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor(context))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryColor(context), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AttendanceProvider, SitesProvider>(
      builder: (context, data, sitesData, _) {
        final attendanceByLabour = data.attendanceMap;
        final sites = sitesData.sites;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        // All labours are available every morning — no permanent site assignment.
        // Site is only recorded on the attendance record for that day.
        final List<Labour> allLabours = data.labours;

        // Apply search filter (only relevant in marking mode)
        final filteredLabours = _searchQuery.isEmpty
            ? allLabours
            : allLabours.where((l) =>
                l.name.toLowerCase().contains(_searchQuery) ||
                l.phone.contains(_searchQuery)).toList();

        // Pending/unmarked group is interpreted as: "available at this moment".
        // Provider already excludes pending from attendanceMap for UI, but we still keep
        // the logic defensive and aligned with the desired behaviour.
        final pendingList = filteredLabours.where((l) {
          final s = attendanceByLabour[l.id];
          return s == null || s == 'pending';
        }).toList();

        // Marked statuses today (present/absent/half) — used for safety net.
        final markedList = filteredLabours.where((l) {
          final s = attendanceByLabour[l.id];
          return s != null && s != 'pending';
        }).toList();

        // Helper to resolve the status of a labour at the currently selected site
        String? getStatusAtSelectedSite(String labourId) {
          if (_selectedSiteId == null) return null;
          final summary = data.dailyShiftMap[labourId];
          if (summary == null) return null;
          final visit = summary.siteVisits.where((v) => v.siteId == _selectedSiteId).firstOrNull;
          return visit?.status;
        }

        // Group B: marked at selected site today
        final List<Labour> markedAtSelectedSite = _selectedSiteId == null
            ? <Labour>[]
            : filteredLabours.where((l) {
                final statusHere = getStatusAtSelectedSite(l.id);
                return statusHere != null && statusHere != 'pending';
              }).toList();

        // Group A: available to mark here (either not marked anywhere today OR has remaining capacity < 1.0)
        final List<Labour> availableToMarkHere = _selectedSiteId == null
            ? <Labour>[]
            : filteredLabours.where((l) {
                // If they are already marked at the selected site today, they are in Group B, not Group A.
                final statusHere = getStatusAtSelectedSite(l.id);
                if (statusHere != null && statusHere != 'pending') return false;

                // Check remaining capacity today
                final summary = data.dailyShiftMap[l.id];
                if (summary == null) return true; // Not marked anywhere today

                final remainingCapacity = 1.0 - summary.totalShiftFactor;
                return remainingCapacity >= 0.5 - 0.001; // Can still work at least another half day
              }).toList();


        // Stats across all labours for today
        final presentCount = attendanceByLabour.values.where((v) => v == 'present').length;
        final absentCount  = attendanceByLabour.values.where((v) => v == 'absent').length;
        final halfDayCount = attendanceByLabour.values.where((v) => v == 'half').length;
        final totalMarked  = presentCount + absentCount + halfDayCount;
        final totalLabours = allLabours.length;

        // Calculate total cost (simplified for demo: sum of daily wages for present/half labours)
        double totalCost = 0;
        for (final l in allLabours) {
          final summary = data.dailyShiftMap[l.id];
          if (summary != null) {
            totalCost += l.dailyWage * summary.totalShiftFactor;
          }
        }

        // How many labours marked at each site today
        final markedBySite = <String, int>{};
        for (final entry in data.siteMap.entries) {
          if (attendanceByLabour.containsKey(entry.key) && entry.value.isNotEmpty) {
            markedBySite[entry.value] = (markedBySite[entry.value] ?? 0) + 1;
          }
        }

        return Scaffold(
          backgroundColor: isDark ? Colors.transparent : AppColors.backgroundColor(context),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
              _buildDateBar(context, data),

              // ── SITE PICKER MODE (no site selected) ──────────────────────
              if (_selectedSiteId == null)
                Expanded(
                  child: _buildSitePickerBody(
                    data: data,
                    sites: sites,
                    markedBySite: markedBySite,
                    totalMarkedToday: totalMarked,
                    isLoading: data.isLoading,
                    totalLabours: totalLabours,
                  ),
                )

              // ── MARKING MODE (site selected) ──────────────────────────────
              else ...[
                _buildStatsBar(presentCount, absentCount, halfDayCount, totalLabours, totalMarked),
                const SizedBox(height: 12),
                _buildActiveSiteHeader(sites, data, availableToMarkHere),
                _buildSearchBar(),
                Expanded(
                  child: data.isLoading && data.labours.isEmpty
                      ? const ShimmerList(count: 5, height: 110)
                      : data.labours.isEmpty
                          ? const EmptyState(
                              icon: Icons.fact_check_outlined,
                              title: 'No Labour Added',
                              subtitle: 'Add labours first to mark attendance.',
                            )
                          : RefreshIndicator(
                              color: AppColors.primaryColor(context),
                              onRefresh: data.initialize,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  _buildTempLabourButton(data),
                                  const SizedBox(height: 8),

                                  // ── Group A + Group B (per selected site) ──

                                  Builder(
                                    builder: (_) {
                                      final groupA = availableToMarkHere;
                                      final groupB = markedAtSelectedSite;
                                      final hasBothEmpty = groupA.isEmpty && groupB.isEmpty;

                                      if (hasBothEmpty && _searchQuery.isEmpty) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Text(
                                              'No labours for this site',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondaryColor(context)),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (_searchQuery.isEmpty && groupA.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    'Available here — ${groupA.length}',
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondaryColor(context)),
                                                  ),
                                                  const Spacer(),
                                                  Text('Not marked anywhere today', style: TextStyle(fontSize: 11, color: AppColors.textTertiaryColor(context))),
                                                ],
                                              ),
                                            ),

                                          ...groupA.asMap().entries.map((entry) => Padding(
                                                key: ValueKey('card_groupA_${entry.value.id}_$_selectedSiteId'),
                                                padding: const EdgeInsets.only(bottom: 10),
                                                child: _AttendanceCard(
                                                  labour: entry.value,
                                                  status: getStatusAtSelectedSite(entry.value.id),
                                                  remark: data.remarkMap[entry.value.id] ?? '',
                                                  data: data,
                                                  siteId: _selectedSiteId ?? '',
                                                  index: entry.key,
                                                ),
                                              )),

                                          if (_searchQuery.isEmpty && groupB.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            _buildSectionHeader('Marked here today', Icons.check_circle_outline, AppColors.successColor(context)),
                                            const SizedBox(height: 8),
                                            ...groupB.map((labour) => Padding(
                                                  key: ValueKey('card_groupB_${labour.id}_$_selectedSiteId'),
                                                  padding: const EdgeInsets.only(bottom: 10),
                                                  child: _AttendanceCard(
                                                    labour: labour,
                                                    status: getStatusAtSelectedSite(labour.id),
                                                    remark: data.remarkMap[labour.id] ?? '',
                                                    data: data,
                                                    siteId: _selectedSiteId ?? '',
                                                  ),
                                                )),
                                          ],

                                          if (_searchQuery.isEmpty && groupA.isEmpty && groupB.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 10, bottom: 12),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: AppColors.softGold(context).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: AppColors.primaryColor(context).withValues(alpha: 0.25)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.verified_rounded, color: AppColors.primaryColor(context), size: 20),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Site Complete',
                                                      style: TextStyle(color: AppColors.primaryColor(context), fontWeight: FontWeight.w700, fontSize: 14),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),

                                  // Temp labours for today
                                  if (data.tempLabours.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildSectionHeader('Today\'s Temp Workers', Icons.person_outline, Colors.purple),
                                    const SizedBox(height: 8),
                                    ...data.tempLabours.map((entry) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _TempLabourCard(
                                        entry: entry,
                                        onDelete: () => data.deleteTempLabour(entry.id),
                                        onTap: () => _showTempPaymentSheet(data, entry),
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
          )),
          bottomNavigationBar: _selectedSiteId != null ? _buildStickyFooter(totalMarked, totalLabours, totalCost) : null,
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

  Widget _buildStickyFooter(int marked, int total, double totalCost) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryColor(context),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -10)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Marked', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('$marked/$total', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Cost', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('₹${totalCost.toStringAsFixed(0)}', style: TextStyle(color: AppColors.primaryColor(context), fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryColor(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                HapticUtils.light();
                AppSnackBar.showSuccess(context, 'Attendance Saved Successfully!');
                setState(() => _selectedSiteId = null); // Return to site picker
              },
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Site Picker (fullscreen, shown when no site is selected) ────────────
  Widget _buildSitePickerBody({
    required AttendanceProvider data,
    required List<SiteModel> sites,
    required Map<String, int> markedBySite,
    required int totalMarkedToday,
    required bool isLoading,
    required int totalLabours,
  }) {
    // Apply search and filters
    final filteredSites = sites.where((s) {
      if (_siteSearchQuery.isNotEmpty && !s.name.toLowerCase().contains(_siteSearchQuery)) {
        return false;
      }
      final count = markedBySite[s.id] ?? 0;
      if (_siteFilter == 'pending' && count > 0) return false;
      if (_siteFilter == 'completed' && count == 0) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlobalSummary(data, sites.length, totalLabours, totalMarkedToday),
        
        // Search and Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                controller: _siteSearchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration('Search sites...', Icons.search),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed', 'completed'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

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
        else if (filteredSites.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No Sites Found',
              subtitle: 'Try adjusting your search or filters.',
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              itemCount: filteredSites.length,
              itemBuilder: (_, i) {
                final site = filteredSites[i];
                final count = markedBySite[site.id] ?? 0;

                return AttendanceSiteRow(
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _siteFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticUtils.light();
        setState(() => _siteFilter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor(context) : AppColors.surfaceElevatedColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primaryColor(context) : AppColors.borderColor(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? (isDark ? AppColors.textPrimaryColor(context) : const Color(0xFFFFFFFF)) 
                : (isDark ? Colors.white70 : AppColors.textSecondaryColor(context)),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalSummary(AttendanceProvider data, int totalSites, int totalLabours, int totalMarked) {
    int completed = 0;
    int pending = totalSites;
    // A site is 'completed' if all its assigned labours are marked.
    // However, since labours aren't strictly assigned to sites, we'll say a site is 'completed' 
    // if at least one labour is marked there today, or we just show active sites vs total sites.
    // Let's use marked sites as completed for now.
    final markedSites = data.siteMap.values.where((v) => v.isNotEmpty).toSet();
    completed = markedSites.length;
    pending = (totalSites > completed) ? totalSites - completed : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateTime.now().day} ${_monthName(DateTime.now().month)} ${DateTime.now().year}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimaryColor(context)),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.borderColor(context)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('$totalSites Sites', Icons.business_rounded, AppColors.textPrimaryColor(context)),
              _summaryItem('$totalLabours Labour', Icons.people_alt_rounded, AppColors.textPrimaryColor(context)),
              _summaryItem('$completed Completed', Icons.check_circle_outline, AppColors.successColor(context)),
              _summaryItem('$pending Pending', Icons.schedule_rounded, AppColors.textTertiaryColor(context)),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.borderColor(context)),
        ],
      ),
    );
  }

  Widget _summaryItem(String text, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(text, 
               textAlign: TextAlign.center,
               style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _monthName(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // ── Active Site Header (shown when a site IS selected) ──────────────────
  Widget _buildActiveSiteHeader(List<SiteModel> sites, AttendanceProvider data, List<Labour> availableLabours) {
    SiteModel? site;
    try { site = sites.firstWhere((s) => s.id == _selectedSiteId); } catch (_) {}

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticUtils.light();
                setState(() { _selectedSiteId = null; _searchController.clear(); });
              },
              child: Icon(Icons.chevron_left, size: 20, color: AppColors.textSecondaryColor(context)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.location_on_rounded, size: 16, color: AppColors.primaryColor(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                site?.name ?? _selectedSiteId ?? '',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimaryColor(context)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            _buildActionMenu(data, availableLabours, sites),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenu(AttendanceProvider data, List<Labour> availableLabours, List<SiteModel> sites) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondaryColor(context), size: 20),
      color: AppColors.surfaceElevatedColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 40),
      onSelected: (val) async {
        if (val == 'allowances') {
            _showAllowanceSheet(data, sites);
        } else if (val == 'mark_all') {
            if (availableLabours.isEmpty) {
              AppSnackBar.showError(context, 'No available labours to mark.');
              return;
            }
            if (_selectedSiteId == null) return;
            HapticUtils.light();
            
            final futures = <Future<void>>[];
            for (final labour in availableLabours) {
              final summary = data.dailyShiftMap[labour.id];
              final totalOtherFactor = summary?.totalShiftFactor ?? 0.0;
              final availableCapacity = 1.0 - totalOtherFactor;
              
              if (availableCapacity <= 0) continue;
              
              String statusToMark = 'present';
              if (availableCapacity < 1.0) {
                 if (availableCapacity >= 0.75) {
                   statusToMark = 'three_quarter';
                 } else if (availableCapacity >= 0.5) statusToMark = 'half';
                 else if (availableCapacity >= 0.25) statusToMark = 'quarter';
              }

              futures.add(data.markAttendance(
                labour.id,
                statusToMark,
                siteId: _selectedSiteId ?? '',
              ));
            }
            await Future.wait(futures);
            
            if (mounted) {
              AppSnackBar.showSuccess(context, 'Marked ${availableLabours.length} labours as Present');
            }
        } else if (val == 'copy') {
            if (_selectedSiteId == null) return;
            HapticUtils.light();
            await data.copyYesterdayAttendance(availableLabours, _selectedSiteId!);
            if (mounted) {
              AppSnackBar.showSuccess(context, 'Copied yesterday\'s attendance');
            }
        } else if (val == 'reset') {
            if (_selectedSiteId == null) return;
            HapticUtils.light();
            
            int count = 0;
            final futures = <Future<void>>[];
            for (final summary in data.dailyShiftMap.values) {
              final visitIndex = summary.siteVisits.indexWhere((v) => v.siteId == _selectedSiteId);
              if (visitIndex >= 0) {
                futures.add(data.markAsPending(summary.labourId, siteId: _selectedSiteId!));
                count++;
              }
            }
            await Future.wait(futures);
            
            if (mounted) {
              if (count > 0) {
                AppSnackBar.showSuccess(context, 'Reset $count attendance records here');
              } else {
                AppSnackBar.showSuccess(context, 'No attendance to reset here');
              }
            }
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'allowances',
          child: Row(children: [Icon(Icons.payments_outlined, color: AppColors.primaryColor(context), size: 18), const SizedBox(width: 8), Text('Allowances', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 13))]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'mark_all',
          child: Row(children: [Icon(Icons.done_all_rounded, color: AppColors.successColor(context), size: 18), const SizedBox(width: 8), Text('Mark All Present', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 13))]),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(children: [Icon(Icons.copy_rounded, color: AppColors.textTertiaryColor(context), size: 18), const SizedBox(width: 8), Text('Copy Yesterday', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 13))]),
        ),
        PopupMenuItem(
          value: 'reset',
          child: Row(children: [Icon(Icons.refresh_rounded, color: AppColors.errorColor(context), size: 18), const SizedBox(width: 8), Text('Reset Attendance', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 13))]),
        ),
      ],
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
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () { HapticUtils.light(); _showAddTempLabourDialog(data); },
        icon: Icon(Icons.person_add_alt_1_rounded, size: 14, color: AppColors.primaryColor(context)),
        label: Text('Add Temp Labour', style: TextStyle(color: AppColors.primaryColor(context), fontWeight: FontWeight.w700, fontSize: 12)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? AppColors.surfaceColor(context) : const Color(0xFFEEF4FA);
    final borderColor = isDark ? AppColors.primaryColor(context).withValues(alpha: 0.2) : const Color(0xFFD4E1EE);
    final headingColor = isDark ? AppColors.primaryColor(context) : const Color(0xFF132B4F);
    final accentColor = isDark ? AppColors.primaryColor(context) : const Color(0xFFF2A900);

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () { HapticUtils.light(); setState(() => _safetyNetExpanded = !_safetyNetExpanded); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(Icons.security_rounded, size: 18, color: accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Already Marked Today — ${markedList.length}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: headingColor)),
                        Text('Tap to review & fix before day locks',
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.primaryColor(context) : const Color(0xFF64809E))),
                      ],
                    ),
                  ),
                  Icon(_safetyNetExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: accentColor),
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
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _searchController,
          style: TextStyle(fontSize: 13, color: AppColors.textPrimaryColor(context)),
          decoration: InputDecoration(
            hintText: 'Search labour...',
            hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiaryColor(context)),
            prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppColors.textTertiaryColor(context)),
            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiaryColor(context)),
                    onPressed: () { _searchController.clear(); HapticUtils.light(); },
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            filled: true,
            fillColor: AppColors.cardColor(context),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor(context))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primaryColor(context), width: 1.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(int present, int absent, int half, int total, int marked) {
    if (total == 0) return const SizedBox.shrink();
    final unmarked = total - marked;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          _statChip('$total Labour', AppColors.primaryColor(context)),
          _statChip('$unmarked Pending', AppColors.textTertiaryColor(context)),
          _statChip('$present Present', AppColors.successColor(context)),
          _statChip('$half Half Day', AppColors.warningColor(context)),
          _statChip('$absent Absent', AppColors.errorColor(context)),
        ],
      ),
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }



  Widget _buildDateBar(BuildContext context, AttendanceProvider data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primaryColor(context)),
              const SizedBox(width: 6),
              Text(AppDateUtils.toDisplay(data.selectedDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryColor(context))),
            ],
          ),
          GestureDetector(
            onTap: () async {
              HapticUtils.light();
              final picked = await showDatePicker(
                context: context,
                initialDate: data.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                builder: (ctx, child) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: isDark 
                          ? ColorScheme.dark(
                              primary: AppColors.primaryColor(context),
                              surface: AppColors.surfaceColor(context),
                              onSurface: AppColors.textPrimaryColor(context),
                            )
                          : ColorScheme.light(
                              primary: AppColors.primaryColor(context),
                              surface: AppColors.surfaceColor(context),
                              onSurface: AppColors.textPrimaryColor(context),
                            ),
                        dialogBackgroundColor: AppColors.surfaceColor(context),
                      ),
                      child: child!,
                    ),
                  );
                },
              );
              if (picked != null) data.changeDate(picked);
            },
            child: Text('Change', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryColor(context))),
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
          Expanded(child: _SummaryChip(label: 'Present', count: present, color: AppColors.successColor(context), bg: AppColors.successColor(context).withValues(alpha: 0.15))),
          const SizedBox(width: 8),
          Expanded(child: _SummaryChip(label: 'Absent', count: absent, color: AppColors.errorColor(context), bg: AppColors.errorColor(context).withValues(alpha: 0.15))),
          const SizedBox(width: 8),
          Expanded(child: _SummaryChip(label: 'Half Day', count: half, color: AppColors.warningColor(context), bg: AppColors.warningColor(context).withValues(alpha: 0.15))),
        ],
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
    final summary = data.dailyShiftMap[labour.id];
    final thisSiteVisit = summary?.siteVisits.where((v) => v.siteId == siteId).firstOrNull;
    final factorHere = thisSiteVisit?.factor ?? 0.0;
    final totalOtherFactor = (summary?.totalShiftFactor ?? 0.0) - factorHere;
    final availableCapacity = 1.0 - totalOtherFactor;

    final color = status == 'present' ? AppColors.successColor(context) :
                  status == 'three_quarter' ? Colors.teal :
                  status == 'half' ? AppColors.warningColor(context) :
                  status == 'quarter' ? Colors.orangeAccent :
                  AppColors.errorColor(context);
    final label = status == 'present' ? 'Present (1.0)' :
                  status == 'three_quarter' ? '3/4 Day' :
                  status == 'half' ? 'Half Day' :
                  status == 'quarter' ? '1/4 Day' :
                  'Absent';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(labour.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimaryColor(context))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                        ),
                        if (siteName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.softGold(context), borderRadius: BorderRadius.circular(6)),
                            child: Text(siteName, style: TextStyle(fontSize: 10, color: AppColors.primaryColor(context), fontWeight: FontWeight.w600)),
                          ),
                        if (remark.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('"$remark"',
                                style: TextStyle(fontSize: 10, color: AppColors.textTertiaryColor(context), fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (availableCapacity >= 1.0) ...[
                _miniStatusBtn('1', status == 'present', AppColors.successColor(context), () => data.markAttendance(labour.id, 'present', siteId: siteId)),
                const SizedBox(width: 4),
              ],
              if (availableCapacity >= 0.75) ...[
                _miniStatusBtn('¾', status == 'three_quarter', Colors.teal, () => data.markAttendance(labour.id, 'three_quarter', siteId: siteId)),
                const SizedBox(width: 4),
              ],
              if (availableCapacity >= 0.5) ...[
                _miniStatusBtn('½', status == 'half', AppColors.warningColor(context), () => data.markAttendance(labour.id, 'half', siteId: siteId)),
                const SizedBox(width: 4),
              ],
              if (availableCapacity >= 0.25) ...[
                _miniStatusBtn('¼', status == 'quarter', Colors.orangeAccent, () => data.markAttendance(labour.id, 'quarter', siteId: siteId)),
                const SizedBox(width: 4),
              ],
              _miniStatusBtn('0', status == 'absent', AppColors.errorColor(context), () => data.markAttendance(labour.id, 'absent', siteId: siteId)),
              const Spacer(),
              // Reset-to-pending undo button
              _miniResetBtn(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatusBtn(String label, bool selected, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))] : [],
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : color)),
        ),
      ),
    );
  }

  Widget _miniResetBtn(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.undo_rounded, color: AppColors.textSecondaryColor(context), size: 20),
                const SizedBox(width: 8),
                const Text('Reset Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              'This will reset ${labour.name}\'s attendance to Pending (unmarked). '
              'They will reappear in the available list. No data is deleted.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryColor(context)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textSecondaryColor(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reset'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          data.markAsPending(labour.id, siteId: siteId);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor(context), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.undo_rounded, size: 16, color: AppColors.textSecondaryColor(context)),
            const SizedBox(width: 6),
            Text('Reset', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _TempLabourCard extends StatelessWidget {
  const _TempLabourCard({
    required this.entry,
    required this.onDelete,
    required this.onTap,
  });

  final TempLabourEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.purple.shade900.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.shade500.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.purple.shade500, Colors.purple.shade700]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade500,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('TEMP', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildInfoBadge(Icons.currency_rupee, '₹${entry.totalWage.toStringAsFixed(0)}', Colors.greenAccent),
                    _buildInfoBadge(Icons.timer_outlined, '${entry.attendanceUnit} Day', AppColors.primaryColor(context)),
                    if (entry.paymentStatus == 'paid')
                      _buildInfoBadge(Icons.check_circle_outline, 'Paid', Colors.green)
                    else if (entry.paymentStatus == 'partial_paid')
                      _buildInfoBadge(Icons.timelapse_rounded, 'Partial (₹${entry.paidAmount.toStringAsFixed(0)})', Colors.orangeAccent)
                    else
                      _buildInfoBadge(Icons.pending_actions, 'Unpaid', Colors.redAccent),
                  ],
                ),
                if (entry.remarks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${entry.remarks}"',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Temp Entry?'),
                  content: Text('Are you sure you want to delete ${entry.name}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                onDelete();
              }
            },
          ),
        ],
      ),
    ),
  );
}

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
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
    this.siteId = '',
    this.isTemp = false,
    this.index = 0,
  });

  final Labour labour;
  final String? status;
  final String remark;
  final AttendanceProvider data;
  final bool isTemp;
  final String siteId;
  final int index;

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class AttendanceStyle {
  final Color fg;
  final Color bg;
  final Color border;
  final Color cardBg;
  const AttendanceStyle(this.fg, this.bg, this.border, this.cardBg);

  static AttendanceStyle get(BuildContext context, String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      Color fg = status == 'present' ? const Color(0xFF00C985) :
                 status == 'three_quarter' ? Colors.teal :
                 status == 'half' ? const Color(0xFFF2A900) :
                 status == 'quarter' ? Colors.orangeAccent :
                 const Color(0xFFFF4D5A);
      return AttendanceStyle(fg, fg.withValues(alpha: 0.1), fg.withValues(alpha: 0.3), AppColors.cardColor(context));
    } else {
      switch (status) {
        case 'present': return const AttendanceStyle(Color(0xFF00A878), Color(0xFFE7F8F2), Color(0xFF9DE5D0), Color(0xFFF0FBF7));
        case 'three_quarter': return const AttendanceStyle(Color(0xFF008F95), Color(0xFFE5F6F7), Color(0xFF8FD8DB), Color(0xFFF2FAFB));
        case 'half': return const AttendanceStyle(Color(0xFFE39A00), Color(0xFFFFF4D9), Color(0xFFF2C56A), Color(0xFFFFF9EC));
        case 'quarter': return const AttendanceStyle(Color(0xFFE68A00), Color(0xFFFFF0DF), Color(0xFFFFD49A), Color(0xFFFFF8EE));
        case 'absent': return const AttendanceStyle(Color(0xFFE83D5B), Color(0xFFFFE9EE), Color(0xFFFF9CAF), Color(0xFFFFF4F6));
        default: return const AttendanceStyle(Color(0xFF64809E), Color(0xFFF0F4F8), Color(0xFFC8D6E3), Color(0xFFFFFFFF));
      }
    }
  }
}

class _AttendanceCardState extends State<_AttendanceCard> {
  bool _localDismissed = false;

  bool _canMark(String status, double availableCapacity) {
    double needed = status == 'present' ? 1.0 : (status == 'half' ? 0.5 : 0.0);
    if (needed > availableCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough shift capacity. Available: $availableCapacity'),
          backgroundColor: Colors.redAccent,
        )
      );
      return false; // Prevent dismiss
    }
    return true;
  }

  Future<void> _performMark(String status) async {
    HapticUtils.select();
    try {
      await widget.data.markAttendance(widget.labour.id, status, remark: widget.remark, siteId: widget.siteId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        )
      );
      // Revert optimistic UI
      widget.data.changeDate(widget.data.selectedDate);
    }
  }

  Future<bool> _mark(String status, double availableCapacity) async {
    if (!_canMark(status, availableCapacity)) return false;
    _performMark(status);
    return true;
  }

  void _showRemarksSheet() {
    final TextEditingController remarkCtrl = TextEditingController(text: widget.remark);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24, left: 24, right: 24,
        ),
        decoration: BoxDecoration(
          color: AppColors.textPrimaryColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('+ Add Site Work Description', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ['Tile fixing', 'Plaster work', 'Slab casting', 'Electrical work'].map((tag) {
                return GestureDetector(
                  onTap: () {
                    remarkCtrl.text = tag;
                    widget.data.setRemark(widget.labour.id, tag);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.surfaceColor(context), borderRadius: BorderRadius.circular(20)),
                    child: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: remarkCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Or type custom remark (Optional)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true, fillColor: AppColors.surfaceColor(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (val) {
                widget.data.setRemark(widget.labour.id, val.trim());
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLabourDetailsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: isDark ? AppColors.textPrimaryColor(context) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.labour.name, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF132B4F), fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Worker ID #${widget.labour.id.substring(0, min(5, widget.labour.id.length)).toUpperCase()}', style: TextStyle(color: AppColors.primaryColor(context), fontSize: 14)),
            const SizedBox(height: 24),
            _buildDetailRow('Current Site:', _resolveSiteName(widget.siteId), isDark),
            _buildDetailRow('Labour Type:', widget.labour.type.toString().split('.').last.toUpperCase(), isDark),
            _buildDetailRow('Daily Wage:', '₹${widget.labour.dailyWage}', isDark),
            _buildDetailRow('Joining date', DateFormat('dd MMM yyyy').format(widget.labour.joiningDate), isDark),
            const SizedBox(height: 20),
            if (widget.isTemp)
              Center(
                child: TextButton(
                  onPressed: () {
                    widget.data.deleteTempLabour(widget.labour.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Delete Temp Labour', style: TextStyle(color: Colors.redAccent)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _resolveSiteName(String id) {
    if (id.isEmpty) return 'Unassigned';
    final sites = context.read<SitesProvider>().sites;
    final site = sites.where((s) => s.id == id).firstOrNull;
    return site?.name ?? id;
  }

  Widget _buildDetailRow(String label, String val, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64809E), fontSize: 14)),
          Text(val, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF132B4F), fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_localDismissed) {
      return const SizedBox.shrink();
    }

    final labour = widget.labour;
    final status = widget.status;
    final isMarked = status != null && status != 'pending';
    final initial = labour.name.isNotEmpty ? labour.name[0].toUpperCase() : '?';

    final summary = widget.data.dailyShiftMap[labour.id];
    final thisSiteVisit = summary?.siteVisits.where((v) => v.siteId == widget.siteId).firstOrNull;
    final factorHere = thisSiteVisit?.factor ?? 0.0;
    
    // Calculate total factor ignoring current site
    final totalOtherFactor = (summary?.totalShiftFactor ?? 0.0) - factorHere;
    final availableCapacity = 1.0 - totalOtherFactor;

    final otherVisits = summary?.siteVisits.where((v) => v.siteId != widget.siteId).toList() ?? [];

    final sites = context.watch<SitesProvider>().sites;
    String getSiteName(String siteId) {
      if (siteId.isEmpty) return '';
      try {
        return sites.firstWhere((s) => s.id == siteId).name;
      } catch (_) {
        return siteId;
      }
    }

    // SLIM STATE WHEN MARKED
    if (isMarked) {
      final style = AttendanceStyle.get(context, status ?? '');
      Color statusColor = style.fg;
      String statusLabel = status == 'present' ? '🟢 1.0 DAY' :
                           status == 'three_quarter' ? '🟢 0.75 DAY' :
                           status == 'half' ? '🟡 0.5 DAY' :
                           status == 'quarter' ? '🟡 0.25 DAY' :
                           '🔴 ABSENT';
      
      return GestureDetector(
        onTap: _showLabourDetailsSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isTemp ? Colors.purple.shade900.withValues(alpha: 0.3) : style.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: style.border),
          ),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: statusColor.withValues(alpha: 0.2), radius: 16, child: Text(initial, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labour.name, style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('₹${labour.dailyWage.toStringAsFixed(0)}/day', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12)),
                    if (otherVisits.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: otherVisits.map((v) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primaryColor(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text('${getSiteName(v.siteId)} (${v.factor} shift)', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 9)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _showRemarksSheet,
                    child: Text(widget.remark.isNotEmpty ? 'View Remark' : 'Remarks ▼', style: TextStyle(color: AppColors.primaryColor(context), fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticUtils.light();
                  widget.data.markAsPending(labour.id, siteId: widget.siteId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedColor(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderColor(context), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.undo_rounded, color: AppColors.textSecondaryColor(context), size: 14),
                      const SizedBox(width: 4),
                      Text('Undo', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      );
    }

    // EXPANDED STATE WHEN PENDING
    return GestureDetector(
      onTap: _showLabourDetailsSheet,
      child: Dismissible(
        key: ValueKey('dismiss_${labour.id}_${widget.siteId}'),
        background: _buildSwipeBg(AppColors.successColor(context), Icons.check_circle_outline, Alignment.centerLeft),
        secondaryBackground: _buildSwipeBg(AppColors.errorColor(context), Icons.cancel_outlined, Alignment.centerRight),
        confirmDismiss: (direction) async {
          final targetStatus = (direction == DismissDirection.startToEnd) ? 'present' : 'absent';
          return _canMark(targetStatus, availableCapacity);
        },
        onDismissed: (direction) {
          setState(() {
            _localDismissed = true;
          });
          final targetStatus = (direction == DismissDirection.startToEnd) ? 'present' : 'absent';
          _performMark(targetStatus);
        },
        child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: widget.isTemp ? null : (Theme.of(context).brightness == Brightness.dark ? null : LinearGradient(
            colors: widget.index % 4 == 0 ? const [Color(0xFFF8FBFF), Color(0xFFEFF5FA)] :
                    widget.index % 4 == 1 ? const [Color(0xFFFCFAFF), Color(0xFFF7F5FC)] :
                    widget.index % 4 == 2 ? const [Color(0xFFF8FEFB), Color(0xFFF2FAF8)] :
                                            const [Color(0xFFFAFCFF), Color(0xFFF5F7FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )),
          color: widget.isTemp ? Colors.purple.shade900.withValues(alpha: 0.3) : (Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceElevatedColor(context) : null),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.isTemp ? Colors.purple.shade500 : (Theme.of(context).brightness == Brightness.dark ? AppColors.borderColor(context) : const Color(0xFFD5E2EF))),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: widget.isTemp ? LinearGradient(
                        colors: [Colors.purple.shade500, Colors.purple.shade700],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ) : (Theme.of(context).brightness == Brightness.dark 
                          ? LinearGradient(
                              colors: [AppColors.surfaceColor(context), AppColors.textPrimaryColor(context)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ) 
                          : null),
                      color: (!widget.isTemp && Theme.of(context).brightness != Brightness.dark) ? const Color(0xFF173A61) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(labour.name, style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 17, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                            if (widget.isTemp)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.purple.shade300, borderRadius: BorderRadius.circular(6)),
                                child: const Text('TEMP', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            if (!widget.isTemp && availableCapacity < 1.0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.primaryColor(context).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                child: Text('Cap: $availableCapacity', style: TextStyle(fontSize: 9, color: AppColors.primaryColor(context), fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(widget.isTemp 
                          ? 'Added at 10:45 AM • ₹${labour.dailyWage.toStringAsFixed(0)}/day'
                          : 'Worker ID #${labour.id.substring(0, min(5, labour.id.length)).toUpperCase()} • ₹${labour.dailyWage.toStringAsFixed(0)}/day', 
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondaryColor(context) : const Color(0xFF6685A4), fontSize: 12)),
                        if (otherVisits.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4, runSpacing: 4,
                            children: otherVisits.map((v) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primaryColor(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text('${getSiteName(v.siteId)} (${v.factor} shift)', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 9)),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {},
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (availableCapacity >= 1.0)
                      _actionBtn('1.0', 'present', availableCapacity),
                    if (availableCapacity >= 0.75)
                      _actionBtn('0.75', 'three_quarter', availableCapacity),
                    if (availableCapacity >= 0.5)
                      _actionBtn('0.5', 'half', availableCapacity),
                    if (availableCapacity >= 0.25)
                      _actionBtn('0.25', 'quarter', availableCapacity),
                    _actionBtn('0.0', 'absent', availableCapacity),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBg(Color color, IconData icon, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: Colors.white, size: 36),
    );
  }

  Widget _actionBtn(String label, String status, double availableCapacity) {
    final style = AttendanceStyle.get(context, status);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GestureDetector(
          onTap: () => _mark(status, availableCapacity),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: style.border),
            ),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(color: style.fg, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

class _OvertimeField extends StatefulWidget {
  const _OvertimeField({
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
        color: AppColors.warningColor(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warningColor(context).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_outlined, size: 15, color: AppColors.warningColor(context)),
          const SizedBox(width: 6),
          Text('OT hrs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningColor(context))),
          const SizedBox(width: 10),
          SizedBox(
            width: 64, height: 34,
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,1})?'))],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimaryColor(context)),
              onChanged: _scheduleSend,
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.warningColor(context))),
              ),
            ),
          ),
          if (widget.overtimeRate > 0 && hours > 0) ...[
            const SizedBox(width: 10),
            Text('= ₹${pay.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningColor(context))),
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

  static final _types = ['petrol', 'lunch', 'breakfast', 'tea'];
  static final _typeEmoji = {'petrol': '🚗', 'lunch': '🍽', 'breakfast': '🍳', 'tea': '☕'};
  static final _typeLabel = {'petrol': 'Petrol', 'lunch': 'Lunch', 'breakfast': 'Breakfast', 'tea': 'Tea'};

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
      AppSnackBar.showSuccess(context, 'Allowances saved for ${widget.presentLabours.length} labour${widget.presentLabours.length == 1 ? '' : 's'} ✓');
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: enabled ? AppColors.textPrimaryColor(context) : AppColors.textTertiaryColor(context)),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          prefixText: '₹',
          hintText: '0',
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isAdvance ? Colors.red.shade300 : AppColors.primaryColor(context).withValues(alpha: 0.4))),
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
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSavedThis ? AppColors.successColor(context).withValues(alpha: 0.4) : AppColors.primaryColor(context).withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryColor(context), AppColors.primaryColor(context)]), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryColor(context)), overflow: TextOverflow.ellipsis),
                  if (total > 0)
                    Text('Total: ₹${total.toStringAsFixed(0)}${advance > 0 ? ' · Advance: ₹${advance.toStringAsFixed(0)}' : ''}',
                        style: TextStyle(fontSize: 11, color: AppColors.primaryColor(context), fontWeight: FontWeight.w600)),
                ]),
              ),
              if (isSavedThis)
                Icon(Icons.check_circle_rounded, color: AppColors.successColor(context), size: 18)
              else
                GestureDetector(
                  onTap: isSavingThis ? null : () => _saveLabour(l),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSavingThis ? Colors.grey.shade200 : AppColors.primaryColor(context),
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
                      activeThumbColor: AppColors.primaryColor(context),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(_typeEmoji[type]!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_typeLabel[type]!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? AppColors.textPrimaryColor(context) : AppColors.textSecondaryColor(context)))),
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
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text('No present labours at this site', style: TextStyle(color: AppColors.textSecondaryColor(context))),
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
                Text('${_typeEmoji[type]!} ${_typeLabel[type]!}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimaryColor(context))),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: AppColors.borderColor(context))),
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
                    border: Border.all(color: AppColors.borderColor(context)),
                  ),
                  child: Row(
                    children: [
                      Switch.adaptive(
                        value: on,
                        onChanged: (v) => setState(() => _enabled[key] = v),
                        activeThumbColor: AppColors.primaryColor(context),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(l.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryColor(context)), overflow: TextOverflow.ellipsis)),
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
        decoration: BoxDecoration(
          color: AppColors.textPrimaryColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.borderColor(context), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: AppColors.primaryColor(context), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Daily Allowances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryColor(context))),
                      Text('${widget.siteName} · ${widget.presentLabours.length} labour${widget.presentLabours.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryColor(context))),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.surfaceColor(context), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondaryColor(context)),
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
                color: AppColors.surfaceColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(color: AppColors.primaryColor(context), borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondaryColor(context),
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
                          Text('No present labours at this site', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 14)),
                          const SizedBox(height: 6),
                          Text('Mark labours as present first, then set their allowances here.', style: TextStyle(color: AppColors.textTertiaryColor(context), fontSize: 12), textAlign: TextAlign.center),
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
                color: AppColors.surfaceColor(context),
                border: Border(top: BorderSide(color: AppColors.borderColor(context))),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total (all labours)', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context))),
                      Text('₹${grandTotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryColor(context))),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: AppColors.textSecondaryColor(context))),
                  ),
                  const SizedBox(width: 8),
                  LoadingButton(
                    onPressed: widget.presentLabours.isEmpty ? null : () async {
                      await _saveAll();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor(context),
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
