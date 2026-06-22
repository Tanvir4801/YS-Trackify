import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/labour.dart';
import '../models/site_model.dart';
import '../providers/site_data_provider.dart';
import '../providers/sites_provider.dart';
import '../services/session_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/labour_card.dart';

class LabourScreen extends StatefulWidget {
  const LabourScreen({super.key});

  @override
  State<LabourScreen> createState() => _LabourScreenState();
}

class _LabourScreenState extends State<LabourScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.absent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ));
  }

  List<Labour> _filterLabours(List<Labour> labours) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return labours;
    return labours
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.phoneNumber.toLowerCase().contains(q) ||
            l.role.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteDataProvider>(
      builder: (context, data, _) {
        final filtered = _filterLabours(data.labours);
        final totalWage = data.labours
            .fold<double>(0, (sum, l) => sum + l.dailyWage);

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              try {
                await _showLabourDialog(this.context);
              } catch (_) {
                _showErrorSnackBar('Something went wrong. Please try again.');
              }
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add Labour',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: Column(
            children: [
              _buildSearchBar(),
              _buildWageLiabilityCard(totalWage),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    final contractorId = SessionService.instance.contractorId ??
                        FirebaseAuth.instance.currentUser?.uid ??
                        '';
                    if (contractorId.isNotEmpty) {
                      context.read<SiteDataProvider>().startLabourStream(contractorId);
                    }
                    await Future.delayed(const Duration(milliseconds: 800));
                  },
                  child: data.labours.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height:
                                MediaQuery.of(context).size.height * 0.6,
                            child: EmptyState(
                              icon: Icons.badge_outlined,
                              title: 'No Labour Added',
                              subtitle:
                                  'Add your first worker to get started.',
                              actionLabel: 'Add Labour',
                              onAction: () async {
                                try {
                                  await _showLabourDialog(this.context);
                                } catch (_) {}
                              },
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.6,
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_outlined,
                                          size: 48,
                                          color: AppColors.textTertiary),
                                      SizedBox(height: 12),
                                      Text('No results found',
                                          style:
                                              AppTextStyles.headingMedium),
                                      SizedBox(height: 4),
                                      Text('Try a different search term',
                                          style: AppTextStyles.bodyMedium),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 110),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final labour = filtered[index];
                                return Dismissible(
                                  key: ValueKey(labour.id),
                                  direction: DismissDirection.horizontal,
                                  confirmDismiss: (direction) async {
                                    if (direction ==
                                        DismissDirection.startToEnd) {
                                      try {
                                        await _showLabourDialog(
                                          this.context,
                                          labour: labour,
                                        );
                                      } catch (_) {
                                        _showErrorSnackBar(
                                            'Something went wrong. Please try again.');
                                      }
                                      return false;
                                    }
                                    final shouldDelete =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        title:
                                            const Text('Delete Labour'),
                                        content:
                                            Text('Delete ${labour.name}?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('Cancel',
                                                style: TextStyle(
                                                    color: AppColors
                                                        .textSecondary)),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.absent),
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return shouldDelete ?? false;
                                  },
                                  onDismissed: (direction) async {
                                    if (direction ==
                                            DismissDirection.endToStart &&
                                        mounted) {
                                      try {
                                        await data.deleteLabour(labour.id);
                                      } catch (_) {
                                        _showErrorSnackBar(
                                            'Something went wrong. Please try again.');
                                      }
                                    }
                                  },
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_outlined,
                                            color: AppColors.primary),
                                        SizedBox(width: 8),
                                        Text('Edit',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                            )),
                                      ],
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: AppColors.absent
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Delete',
                                            style: TextStyle(
                                              color: AppColors.absent,
                                              fontWeight: FontWeight.w700,
                                            )),
                                        SizedBox(width: 8),
                                        Icon(Icons.delete_outline,
                                            color: AppColors.absent),
                                      ],
                                    ),
                                  ),
                                  child: LabourCard(
                                    labour: labour,
                                    advanceAmount: labour.advanceAmount,
                                    onTap: () => _showLabourDialog(
                                        this.context,
                                        labour: labour),
                                    onAdvanceTap: () => _showAdvanceDialog(
                                        this.context, labour),
                                    onMenuTap: () =>
                                        _showLabourMenu(labour, data),
                                  ),
                                );
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search workers...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textTertiary, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      size: 18, color: AppColors.textTertiary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildWageLiabilityCard(double totalWage) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.absent.withValues(alpha: 0.07),
            AppColors.halfDay.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.halfDay.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.halfDay.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.halfDay, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Wage Liability',
                    style: AppTextStyles.caption),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: totalWage),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (ctx, val, _) => Text(
                    '₹${val.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.halfDay,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Text('Daily rate total',
              style: AppTextStyles.caption),
        ],
      ),
    );
  }

  void _showLabourMenu(Labour labour, SiteDataProvider data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                )),
            Text(labour.name, style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Edit Labour'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _showLabourDialog(this.context, labour: labour);
                } catch (_) {}
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline,
                  color: AppColors.halfDay),
              title: const Text('Add Advance'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _showAdvanceDialog(this.context, labour);
                } catch (_) {}
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined,
                  color: AppColors.primary),
              title: const Text('Assign Site'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _showSiteAssignDialog(labour, data);
                } catch (_) {
                  _showErrorSnackBar('Something went wrong.');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.absent),
              title: const Text('Delete Labour',
                  style: TextStyle(color: AppColors.absent)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await data.deleteLabour(labour.id);
                } catch (_) {
                  _showErrorSnackBar('Something went wrong.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSiteAssignDialog(
      Labour labour, SiteDataProvider data) async {
    final sitesData = context.read<SitesProvider>();
    final sites = sitesData.sites;

    if (sites.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textSecondary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text(
            'No sites found. Create sites from the Admin Panel first.',
            style: TextStyle(color: Colors.white),
          ),
        ));
      return;
    }

    String? selectedSiteId;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign to Site',
                          style: AppTextStyles.headingMedium),
                      Text(labour.name,
                          style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 8),
              _SiteOptionTile(
                label: 'No Site (Unassigned)',
                icon: Icons.location_off_outlined,
                color: AppColors.textTertiary,
                isSelected: selectedSiteId == null,
                onTap: () => setSheetState(() => selectedSiteId = null),
              ),
              const SizedBox(height: 4),
              ...sites.map((site) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _SiteOptionTile(
                      label: site.name,
                      icon: Icons.location_on_rounded,
                      color: AppColors.primary,
                      isSelected: selectedSiteId == site.id,
                      onTap: () =>
                          setSheetState(() => selectedSiteId = site.id),
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          setSheetState(() => saving = true);
                          try {
                            await data.assignSite(
                              labour.id,
                              selectedSiteId ?? '',
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              final siteName = selectedSiteId == null
                                  ? 'Unassigned'
                                  : sites
                                      .firstWhere(
                                          (s) => s.id == selectedSiteId,
                                          orElse: () => SiteModel(
                                              id: '',
                                              name: 'Unknown',
                                              contractorId: '',
                                              description: ''))
                                      .name;
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.present,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  content: Text(
                                    '${labour.name} assigned to $siteName',
                                    style: const TextStyle(
                                        color: Colors.white),
                                  ),
                                ));
                            }
                          } catch (_) {
                            setSheetState(() => saving = false);
                            _showErrorSnackBar(
                                'Failed to save. Please try again.');
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Assignment',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAdvanceDialog(
      BuildContext context, Labour labour) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Advance — ${labour.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Enter an amount';
              if (double.tryParse(val) == null) return 'Enter a valid number';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(controller.text);
              Navigator.of(ctx).pop();
              try {
                await context.read<SiteDataProvider>().addAdvancePayment(
                      labourId: labour.id,
                      amount: amount,
                    );
              } catch (_) {
                _showErrorSnackBar('Something went wrong. Please try again.');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _showLabourDialog(
    BuildContext context, {
    Labour? labour,
  }) async {
    final nameCtrl =
        TextEditingController(text: labour?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: labour?.phoneNumber ?? '');
    final roleCtrl =
        TextEditingController(text: labour?.role ?? '');
    final skillCtrl =
        TextEditingController(text: labour?.role ?? '');
    final wageCtrl = TextEditingController(
        text: labour != null
            ? labour.dailyWage.toStringAsFixed(0)
            : '');
    final otRateCtrl = TextEditingController(
        text: labour != null
            ? labour.overtimeRate.toStringAsFixed(0)
            : '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title:
            Text(labour == null ? 'Add Labour' : 'Edit Labour'),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: roleCtrl,
                decoration:
                    const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: wageCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Daily Wage (₹) *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: otRateCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                    labelText: 'OT Rate (₹/hr)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final dataProvider = context.read<SiteDataProvider>();
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final role = roleCtrl.text.trim();
              final wage = double.tryParse(wageCtrl.text) ?? 0;
              final otRate =
                  double.tryParse(otRateCtrl.text) ?? 0;

              Navigator.of(ctx).pop();

              try {
                if (labour == null) {
                  await dataProvider.addLabour(
                    name: name,
                    phoneNumber: phone,
                    role: role,
                    dailyWage: wage,
                    overtimeRate: otRate,
                  );
                } else {
                  await dataProvider.updateLabour(
                    labour.copyWith(
                      name: name,
                      phoneNumber: phone,
                      role: role,
                      dailyWage: wage,
                      overtimeRate: otRate,
                    ),
                  );
                }
              } catch (_) {
                _showErrorSnackBar(
                    'Something went wrong. Please try again.');
              }
            },
            child: Text(labour == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    roleCtrl.dispose();
    skillCtrl.dispose();
    wageCtrl.dispose();
    otRateCtrl.dispose();
  }
}

class _SiteOptionTile extends StatelessWidget {
  const _SiteOptionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
