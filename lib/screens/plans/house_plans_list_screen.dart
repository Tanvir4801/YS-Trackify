import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';
import '../../models/house_plan_model.dart';
import '../../providers/branding_provider.dart';
import '../../providers/house_plans_provider.dart';
import '../../services/house_plan_pdf_service.dart';
import '../../services/session_service.dart';
import '../../widgets/animations/bouncy_tap.dart';
import '../../widgets/animations/staggered_list.dart';
import 'house_plan_detail_screen.dart';

class HousePlansListScreen extends StatefulWidget {
  const HousePlansListScreen({super.key});

  @override
  State<HousePlansListScreen> createState() => _HousePlansListScreenState();
}

class _HousePlansListScreenState extends State<HousePlansListScreen> {
  final _searchCtrl = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contractorId = SessionService.instance.contractorId ?? '';
      context.read<HousePlansProvider>().startListening(contractorId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name, double pendingDue) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedPhone = clean.length == 10 ? '91$clean' : clean;
    final message = pendingDue > 0
        ? 'Hello $name, from YS Construction. This is regarding your house plan & site visit pending balance of ${_currencyFmt.format(pendingDue)}.'
        : 'Hello $name, from YS Construction regarding your house plan drawings.';
    final uri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _generatePdf(HousePlanOwner owner) async {
    HapticUtils.select();
    final branding = context.read<BrandingProvider>().branding;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating official PDF Bill...'), duration: Duration(seconds: 1)),
      );
      await HousePlanPdfService.shareBillPdf(owner: owner, branding: branding);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HousePlansProvider>();
    final plans = provider.filteredPlans;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = AppColors.backgroundColor(context);
    final surface = AppColors.surfaceColor(context);
    final border = AppColors.borderColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textMuted = AppColors.mutedTextColor(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by client, town, phone...',
                  hintStyle: TextStyle(fontSize: 14, color: textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (val) => provider.setSearchQuery(val),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'House Plans & Visits',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  Text(
                    '${provider.totalClientsCount} Registered Clients',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: textPrimary),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchCtrl.clear();
                  provider.setSearchQuery('');
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(provider, isDark),

          // Content List
          Expanded(
            child: provider.isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context)))
                : plans.isEmpty
                    ? _buildEmptyState(textPrimary, textMuted)
                    : RefreshIndicator(
                        color: AppColors.primaryColor(context),
                        onRefresh: () async {
                          final contractorId = SessionService.instance.contractorId ?? '';
                          provider.startListening(contractorId);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: plans.length,
                          itemBuilder: (ctx, index) {
                            final owner = plans[index];
                            return _buildOwnerCard(
                              owner: owner,
                              index: index,
                              isDark: isDark,
                              surface: surface,
                              border: border,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(HousePlansProvider provider, bool isDark) {
    final filters = [
      {'id': 'all', 'label': 'All (${provider.totalClientsCount})', 'icon': Icons.layers_rounded},
      {'id': 'visit_due', 'label': 'Visit Due (${provider.visitDueCount})', 'icon': Icons.directions_car_rounded},
      {'id': 'plan_pending', 'label': 'Plan Due (${provider.planPendingCount})', 'icon': Icons.hourglass_top_rounded},
      {'id': 'cleared', 'label': 'Cleared (${provider.clearedCount})', 'icon': Icons.check_circle_rounded},
    ];

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = filters[i];
          final isSelected = provider.selectedFilter == f['id'];
          final label = f['label'] as String;
          final icon = f['icon'] as IconData;

          return BouncyTap(
            onTap: () {
              HapticUtils.select();
              provider.setFilter(f['id'] as String);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFF5A623), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark
                        ? const Color(0xFF132238).withValues(alpha: 0.70)
                        : Colors.white.withValues(alpha: 0.90)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFFD54F).withValues(alpha: 0.6)
                      : (isDark
                          ? const Color(0xFF91AAC8).withValues(alpha: 0.16)
                          : const Color(0xFF0F172A).withValues(alpha: 0.08)),
                  width: 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFFF5A623).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected
                        ? const Color(0xFF1A1305)
                        : (isDark ? const Color(0xFF91A7BE) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF1A1305)
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOwnerCard({
    required HousePlanOwner owner,
    required int index,
    required bool isDark,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final emerald = AppColors.successColor(context);
    final amber = AppColors.warningColor(context);

    // Dynamic ambient glow color based on client status
    Color glowColor;
    if (owner.siteVisits.isNotEmpty && !owner.isVisitsCleared) {
      glowColor = const Color(0xFFF59E0B); // Warm Amber
    } else if (owner.isPlanFeeCleared && owner.netPending <= 0) {
      glowColor = const Color(0xFF10B981); // Emerald Green
    } else {
      glowColor = AppColors.primaryColor(context); // Trackify Gold
    }

    return StaggeredFadeIn(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF16253D).withValues(alpha: 0.82),
                          const Color(0xFF0F1A2A).withValues(alpha: 0.90),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.94),
                          const Color(0xFFF8FAFC).withValues(alpha: 0.84),
                        ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF91AAC8).withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.85),
                  width: 1.2,
                ),
              ),
              child: Stack(
                children: [
                  // Luminous Top Gradient Accent Bar
                  Positioned(
                    top: 0,
                    left: 24,
                    right: 24,
                    height: 2.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            glowColor.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        HapticUtils.light();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HousePlanDetailScreen(ownerId: owner.id)),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Meta Row: Plan # and Badges
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (owner.planNo.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryColor(context).withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.primaryColor(context).withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.explore_outlined, size: 13, color: AppColors.primaryColor(context)),
                                              const SizedBox(width: 4),
                                              Text(
                                                owner.planNo,
                                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor(context)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (owner.villageCity.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.location_on_outlined, size: 13, color: textMuted),
                                            const SizedBox(width: 2),
                                            Text(
                                              owner.villageCity,
                                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMuted),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Multi-Badge Container (Plan Fee Status + Visit Fee Status)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // 1. Plan Fee Badge (Accurate Partial Paid / Cleared)
                                    _buildPlanFeeBadge(owner),

                                    // 2. Site Visit Badge (if visits exist)
                                    if (owner.siteVisits.isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      _buildStatusBadge(
                                        label: owner.isVisitsCleared
                                            ? '✓ VISIT PAID'
                                            : '🚗 VISIT DUE: ${_currencyFmt.format(owner.visitsPending)}',
                                        isSuccess: owner.isVisitsCleared,
                                        isAmber: !owner.isVisitsCleared,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Client Name
                            Text(
                              owner.ownerName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Phone & Plot Area
                            Row(
                              children: [
                                if (owner.ownerPhone.isNotEmpty) ...[
                                  Icon(Icons.phone_outlined, size: 13, color: textMuted),
                                  const SizedBox(width: 4),
                                  Text(owner.ownerPhone, style: TextStyle(fontSize: 12, color: textMuted)),
                                  const SizedBox(width: 12),
                                ],
                                if (owner.plotArea.isNotEmpty) ...[
                                  Icon(Icons.square_foot_rounded, size: 13, color: textMuted),
                                  const SizedBox(width: 4),
                                  Text(owner.plotArea, style: TextStyle(fontSize: 12, color: textMuted)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Drawing Progress Strip (Glass Styled + Multi-color Gradient)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F1A2A).withValues(alpha: 0.65)
                                    : const Color(0xFFF8FAFC).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF91AAC8).withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.layers_outlined, size: 14, color: AppColors.primaryColor(context)),
                                          const SizedBox(width: 6),
                                          Text('House Plans:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
                                        ],
                                      ),
                                      Text(
                                        '${owner.completedPlansCount} of ${owner.totalPlansCount} Done (${(owner.progressPercent * 100).round()}%)',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Multi-color Gradient Progress Bar
                                  Container(
                                    height: 7,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: owner.progressPercent.clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF3B82F6)],
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                              blurRadius: 6,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Financial Overview Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PLAN FEE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.4)),
                                    const SizedBox(height: 2),
                                    Text(_currencyFmt.format(owner.houseAmount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                                  ],
                                ),
                                if (owner.siteVisits.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text('VISITS (${owner.siteVisits.length})', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.4)),
                                      const SizedBox(height: 2),
                                      Text('+${_currencyFmt.format(owner.totalVisitsAmount)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: amber)),
                                    ],
                                  ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      owner.siteVisits.isNotEmpty && owner.isPlanFeeCleared && owner.visitsPending > 0
                                          ? 'VISIT DUE'
                                          : 'PENDING',
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.4),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      owner.netPending <= 0 ? '₹0 PAID' : _currencyFmt.format(owner.netPending),
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: owner.netPending <= 0 ? emerald : amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 22),

                            // Action Row (Bouncy Animated Frosted Glass Buttons)
                            Row(
                              children: [
                                // Call Button
                                if (owner.ownerPhone.isNotEmpty)
                                  _buildMiniAction(
                                    icon: Icons.phone_rounded,
                                    label: 'Call',
                                    onTap: () => _makePhoneCall(owner.ownerPhone),
                                    color: AppColors.primaryColor(context),
                                    isDark: isDark,
                                  ),
                                const SizedBox(width: 8),

                                // WhatsApp Button
                                if (owner.ownerPhone.isNotEmpty)
                                  _buildMiniAction(
                                    icon: Icons.chat_rounded,
                                    label: 'WhatsApp',
                                    onTap: () => _openWhatsApp(owner.ownerPhone, owner.ownerName, owner.netPending),
                                    color: const Color(0xFF25D366),
                                    isDark: isDark,
                                  ),
                                const SizedBox(width: 8),

                                // PDF Bill Button
                                _buildMiniAction(
                                  icon: Icons.picture_as_pdf_rounded,
                                  label: 'Bill PDF',
                                  onTap: () => _generatePdf(owner),
                                  color: Colors.redAccent,
                                  isDark: isDark,
                                ),

                                const Spacer(),

                                // Open Workspace Arrow Button
                                Row(
                                  children: [
                                    Text('Workspace', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor(context))),
                                    Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryColor(context)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isDark,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanFeeBadge(HousePlanOwner owner) {
    if (owner.isPlanFeeCleared) {
      return _buildStatusBadge(
        label: '✓ PLAN FEE CLEARED (100%)',
        isSuccess: true,
      );
    }

    if (owner.planFeePaid > 0 && owner.houseAmount > 0) {
      final pct = ((owner.planFeePaid / owner.houseAmount) * 100).round();
      final label = pct == 50 ? 'HALF PAID (50%)' : 'PARTIAL PAID ($pct%)';
      return _buildStatusBadge(
        label: label,
        isSuccess: false,
        isAmber: true,
      );
    }

    return _buildStatusBadge(
      label: 'PLAN FEE PENDING',
      isSuccess: false,
      isAmber: false,
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required bool isSuccess,
    bool isAmber = false,
  }) {
    final Color color = isSuccess
        ? const Color(0xFF10B981)
        : (isAmber ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.65),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textMuted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.architecture_rounded, size: 56, color: textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No House Plans Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Clients and engineering drawings registered in the Trackify Admin portal will automatically appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
