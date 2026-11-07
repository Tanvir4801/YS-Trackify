import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/haptic_utils.dart';
import '../../models/house_plan_model.dart';
import '../../providers/branding_provider.dart';
import '../../providers/house_plans_provider.dart';
import '../../services/house_plan_pdf_service.dart';
import '../../widgets/animations/bouncy_tap.dart';
import 'widgets/site_visit_bottom_sheet.dart';

class HousePlanDetailScreen extends StatefulWidget {
  final String ownerId;

  const HousePlanDetailScreen({super.key, required this.ownerId});

  @override
  State<HousePlanDetailScreen> createState() => _HousePlanDetailScreenState();
}

class _HousePlanDetailScreenState extends State<HousePlanDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: clean));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone number $clean copied to clipboard'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phone, String name, double pendingDue) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final formattedPhone = clean.length == 10 ? '91$clean' : clean;
    final message = pendingDue > 0
        ? 'Hello $name, from YS Construction. This is regarding your house plan & site visit pending balance of ${_currencyFmt.format(pendingDue)}.'
        : 'Hello $name, from YS Construction regarding your house plan drawing updates.';
    final uri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please check if app is installed.'),
            backgroundColor: Color(0xFF1E293B),
          ),
        );
      }
    }
  }

  Future<void> _generatePdf(HousePlanOwner owner, BrandingData branding) async {
    HapticUtils.select();
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
    final branding = context.watch<BrandingProvider>().branding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find the live owner object from the provider stream
    final owner = provider.allPlans.firstWhere(
      (o) => o.id == widget.ownerId,
      orElse: () => HousePlanOwner(
        id: widget.ownerId,
        contractorId: '',
        ownerName: 'Loading...',
        ownerPhone: '',
      ),
    );

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              owner.ownerName,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (owner.villageCity.isNotEmpty)
              Text(
                '${owner.villageCity} • Plan #${owner.planNo}',
                style: TextStyle(fontSize: 11, color: textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (owner.ownerPhone.isNotEmpty)
            IconButton(
              tooltip: 'Call Client',
              icon: Icon(Icons.phone_rounded, color: AppColors.primaryColor(context), size: 20),
              onPressed: () => _makePhoneCall(owner.ownerPhone),
            ),
          IconButton(
            tooltip: 'Download & Share Bill PDF',
            icon: Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryColor(context)),
            onPressed: () => _generatePdf(owner, branding),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryColor(context),
          labelColor: AppColors.primaryColor(context),
          unselectedLabelColor: textMuted,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'Drawings (${owner.completedPlansCount}/${owner.totalPlansCount})'),
            Tab(text: 'Visits (${owner.siteVisits.length})'),
            const Tab(text: 'Financials'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDrawingsTab(owner, provider, isDark, surface, border, textPrimary, textMuted),
          _buildVisitsTab(owner, provider, isDark, surface, border, textPrimary, textMuted),
          _buildFinancialsTab(owner, isDark, surface, border, textPrimary, textMuted),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryColor(context),
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              label: const Text('Log Visit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              onPressed: () => SiteVisitBottomSheet.show(context, owner: owner, provider: provider),
            )
          : null,
    );
  }

  // ── TAB 1: DRAWINGS CHECKLIST ──
  Widget _buildDrawingsTab(
    HousePlanOwner owner,
    HousePlansProvider provider,
    bool isDark,
    Color surface,
    Color border,
    Color textPrimary,
    Color textMuted,
  ) {
    final completed = owner.completedDrawings;
    final inProgress = owner.inProgressDrawings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick progress summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Drawing Completion Scope',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  Text(
                    '${(owner.progressPercent * 100).round()}% Done',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.successColor(context)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: owner.progressPercent,
                  minHeight: 8,
                  backgroundColor: isDark ? const Color(0xFF0F1A2A) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.successColor(context)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${owner.completedPlansCount} Completed',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successColor(context)),
                  ),
                  Text(
                    '${inProgress.length} In Progress',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warningColor(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // SECTION 1: COMPLETED DRAWINGS (Sorted to Top, Emerald Tint)
        if (completed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: AppColors.successColor(context)),
                const SizedBox(width: 6),
                Text(
                  'COMPLETED DRAWINGS (${completed.length})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.successColor(context), letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          ...completed.map((p) => _buildDrawingItem(
                drawing: p,
                owner: owner,
                provider: provider,
                isCompleted: true,
                isDark: isDark,
                textPrimary: textPrimary,
                textMuted: textMuted,
                border: border,
              )),
          const SizedBox(height: 16),
        ],

        // SECTION 2: IN PROGRESS DRAWINGS
        if (inProgress.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.pending_actions_rounded, size: 16, color: AppColors.warningColor(context)),
                const SizedBox(width: 6),
                Text(
                  'PENDING / IN PROGRESS (${inProgress.length})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warningColor(context), letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          ...inProgress.map((p) => _buildDrawingItem(
                drawing: p,
                owner: owner,
                provider: provider,
                isCompleted: false,
                isDark: isDark,
                textPrimary: textPrimary,
                textMuted: textMuted,
                border: border,
              )),
        ],
      ],
    );
  }

  Widget _buildDrawingItem({
    required HousePlanDrawing drawing,
    required HousePlanOwner owner,
    required HousePlansProvider provider,
    required bool isCompleted,
    required bool isDark,
    required Color textPrimary,
    required Color textMuted,
    required Color border,
  }) {
    final emerald = AppColors.successColor(context);
    final warning = AppColors.warningColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (isCompleted)
            BoxShadow(
              color: emerald.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted
                    ? [
                        emerald.withValues(alpha: isDark ? 0.16 : 0.10),
                        emerald.withValues(alpha: isDark ? 0.08 : 0.04),
                      ]
                    : [
                        isDark ? const Color(0xFF16253D).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.85),
                        isDark ? const Color(0xFF0F1A2A).withValues(alpha: 0.75) : const Color(0xFFF8FAFC).withValues(alpha: 0.80),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCompleted
                    ? emerald.withValues(alpha: 0.45)
                    : (isDark ? const Color(0xFF91AAC8).withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.8)),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Number badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isCompleted ? emerald.withValues(alpha: 0.22) : (isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    drawing.num,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? emerald : textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drawing.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              drawing.category,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: textMuted),
                            ),
                          ),
                          if (drawing.completedDate != null) ...[
                            Text(' • ', style: TextStyle(fontSize: 10, color: textMuted)),
                            Text(
                              'Done ${drawing.completedDate}',
                              style: TextStyle(fontSize: 10, color: emerald, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 1-Tap Toggle Action Button (Bouncy Animated Glass Button)
                BouncyTap(
                  onTap: () async {
                    HapticUtils.select();
                    final newStatus = isCompleted ? 'in_progress' : 'completed';
                    await provider.toggleDrawingStatus(
                      ownerId: owner.id,
                      planId: drawing.id,
                      newStatus: newStatus,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? emerald.withValues(alpha: 0.22)
                          : warning.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCompleted ? emerald.withValues(alpha: 0.55) : warning.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: isCompleted ? emerald : warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCompleted ? 'Done' : 'Mark Done',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? emerald : warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── TAB 2: SITE VISITS LEDGER ──
  Widget _buildVisitsTab(
    HousePlanOwner owner,
    HousePlansProvider provider,
    bool isDark,
    Color surface,
    Color border,
    Color textPrimary,
    Color textMuted,
  ) {
    final visits = owner.siteVisits;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Visits financial banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL VISITS LOGGED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted)),
                      const SizedBox(height: 2),
                      Text('${visits.length} Visit${visits.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TOTAL VISITS FEE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted)),
                      const SizedBox(height: 2),
                      Text(_currencyFmt.format(owner.totalVisitsAmount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryColor(context))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18, color: Colors.black),
                  label: const Text('+ Log Site Visit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor(context),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => SiteVisitBottomSheet.show(context, owner: owner, provider: provider),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (visits.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(Icons.directions_car_filled_rounded, size: 48, color: textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No site visits recorded yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                  const SizedBox(height: 4),
                  Text('Tap below to add a consultation or inspection trip.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textMuted)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.black),
                    label: const Text('Log First Visit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor(context),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => SiteVisitBottomSheet.show(context, owner: owner, provider: provider),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ...visits.asMap().entries.map((entry) {
            final v = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor(context).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.directions_car_rounded, size: 18, color: AppColors.primaryColor(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                v.purpose,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currencyFmt.format(v.amount),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${v.date}',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                        if (v.notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              v.notes,
                              style: TextStyle(fontSize: 11, color: textPrimary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.errorColor(context)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Visit Entry?'),
                          content: Text('Remove ${v.purpose} (${_currencyFmt.format(v.amount)})?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await provider.deleteSiteVisit(ownerId: owner.id, visitId: v.id);
                      }
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          BouncyTap(
            onTap: () => SiteVisitBottomSheet.show(context, owner: owner, provider: provider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryColor(context).withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryColor(context), size: 19),
                  const SizedBox(width: 8),
                  Text(
                    '+ Log Another Site Visit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 70), // space for FAB
        ],
      ],
    );
  }

  // ── TAB 3: FINANCIALS & PAYMENTS ──
  Widget _buildFinancialsTab(
    HousePlanOwner owner,
    bool isDark,
    Color surface,
    Color border,
    Color textPrimary,
    Color textMuted,
  ) {
    final emerald = AppColors.successColor(context);
    final amber = AppColors.warningColor(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 3-Row Comprehensive Breakdown (Same as Web Admin)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PAYMENT & FINANCIAL BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 16),

              // Row 1: Agreed House Plan Fee
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('House Plan Fee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      Text(
                        owner.isPlanFeeCleared ? '✓ 100% Cleared' : 'Due: ${_currencyFmt.format(owner.planFeePending)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: owner.isPlanFeeCleared ? emerald : amber),
                      ),
                    ],
                  ),
                  Text(_currencyFmt.format(owner.houseAmount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                ],
              ),
              const Divider(height: 24),

              // Row 2: Site Visits
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Site Visits (${owner.siteVisits.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      Text(
                        owner.siteVisits.isEmpty
                            ? 'No visits charged'
                            : (owner.isVisitsCleared ? '✓ Cleared' : 'Pending: ${_currencyFmt.format(owner.visitsPending)}'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: owner.isVisitsCleared ? emerald : amber),
                      ),
                    ],
                  ),
                  Text('+${_currencyFmt.format(owner.totalVisitsAmount)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                ],
              ),
              const Divider(height: 24),

              // Row 3: Totals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Billable', style: TextStyle(fontSize: 11, color: textMuted), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(_currencyFmt.format(owner.totalBillableAmount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Received', style: TextStyle(fontSize: 11, color: textMuted), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(_currencyFmt.format(owner.calculatedTotalPaid), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: emerald), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          owner.siteVisits.isNotEmpty && owner.isPlanFeeCleared && owner.visitsPending > 0
                              ? 'Visit Due'
                              : 'Remaining',
                          style: TextStyle(fontSize: 11, color: textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          owner.netPending <= 0 ? '₹0 PAID' : _currencyFmt.format(owner.netPending),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: owner.netPending <= 0 ? emerald : amber,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick WhatsApp Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _openWhatsApp(owner.ownerPhone, owner.ownerName, owner.netPending),
            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
            label: const Text('Send WhatsApp Payment Reminder', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
