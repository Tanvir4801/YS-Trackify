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
      {'id': 'all', 'label': 'All (${provider.totalClientsCount})'},
      {'id': 'visit_due', 'label': '🚗 Visit Due (${provider.visitDueCount})'},
      {'id': 'plan_pending', 'label': '⏳ Plan Due (${provider.planPendingCount})'},
      {'id': 'cleared', 'label': '✓ Cleared (${provider.clearedCount})'},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = filters[i];
          final isSelected = provider.selectedFilter == f['id'];
          return ChoiceChip(
            label: Text(
              f['label']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primaryColor(context),
            backgroundColor: isDark ? const Color(0xFF132238) : const Color(0xFFF1F5F9),
            onSelected: (_) {
              HapticUtils.select();
              provider.setFilter(f['id']!);
            },
          );
        },
      ),
    );
  }

  Widget _buildOwnerCard({
    required HousePlanOwner owner,
    required bool isDark,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textMuted,
  }) {
    final emerald = AppColors.successColor(context);
    final amber = AppColors.warningColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticUtils.light();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HousePlanDetailScreen(ownerId: owner.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row: Plan # and Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (owner.planNo.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primaryColor(context).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.explore_outlined, size: 12, color: AppColors.primaryColor(context)),
                                const SizedBox(width: 4),
                                Text(
                                  owner.planNo,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryColor(context)),
                                ),
                              ],
                            ),
                          ),
                        if (owner.villageCity.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 12, color: textMuted),
                              const SizedBox(width: 2),
                              Text(owner.villageCity, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // Multi-Badge Container (Plan Fee Status + Visit Fee Status)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 1. Plan Fee Badge
                        _buildStatusBadge(
                          label: owner.isPlanFeeCleared
                              ? '✓ PLAN FEE CLEARED'
                              : (owner.planFeePaid >= owner.houseAmount * 0.5
                                  ? 'HALF PAID (${(owner.planFeePaid / owner.houseAmount * 100).round()}%)'
                                  : 'PLAN FEE PENDING'),
                          isSuccess: owner.isPlanFeeCleared,
                        ),

                        // 2. Site Visit Badge (if visits exist)
                        if (owner.siteVisits.isNotEmpty) ...[
                          const SizedBox(height: 4),
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
                const SizedBox(height: 12),

                // Client Name
                Text(
                  owner.ownerName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.3,
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

                // Drawing Progress Strip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: owner.progressPercent,
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(emerald),
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
                        Text('PLAN FEE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textMuted)),
                        const SizedBox(height: 2),
                        Text(_currencyFmt.format(owner.houseAmount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    if (owner.siteVisits.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('VISITS (${owner.siteVisits.length})', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textMuted)),
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
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          owner.netPending <= 0 ? '₹0 PAID' : _currencyFmt.format(owner.netPending),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: owner.netPending <= 0 ? emerald : amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Action Row
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
                        Text('Workspace', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryColor(context))),
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
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticUtils.select();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required bool isSuccess,
    bool isAmber = false,
  }) {
    Color bg;
    Color border;
    Color text;

    if (isSuccess) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      border = const Color(0xFF10B981).withValues(alpha: 0.3);
      text = const Color(0xFF10B981);
    } else if (isAmber) {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      border = const Color(0xFFF59E0B).withValues(alpha: 0.3);
      text = const Color(0xFFF59E0B);
    } else {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      border = const Color(0xFFEF4444).withValues(alpha: 0.3);
      text = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: text, letterSpacing: 0.3),
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
