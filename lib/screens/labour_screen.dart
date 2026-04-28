import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/labour.dart';
import '../providers/site_data_provider.dart';

class LabourScreen extends StatefulWidget {
  const LabourScreen({super.key});

  @override
  State<LabourScreen> createState() => _LabourScreenState();
}

class _LabourScreenState extends State<LabourScreen> {
  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteDataProvider>(
      builder: (context, data, _) {
        return Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              try {
                await _showLabourDialog(this.context);
              } catch (_) {
                _showErrorSnackBar('Something went wrong. Please try again.');
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Labour'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Card(
                  color: AppColors.redCard,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 155, 71, 71)
                                .withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Color.fromARGB(255, 230, 200, 195),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rs ${data.totalAdvancePaid.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.absent,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Across all workers',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.absent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: data.labours.isEmpty
                    ? const Center(child: Text('No labour added yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                        itemCount: data.labours.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final labour = data.labours[index];
                          return Dismissible(
                            key: ValueKey(labour.id),
                            direction: DismissDirection.horizontal,
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
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

                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Labour'),
                                  content: Text('Delete ${labour.name}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
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
                              if (direction == DismissDirection.endToStart &&
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined,
                                      color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: AppColors.absent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: AppColors.absent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.delete_outline,
                                      color: AppColors.absent),
                                ],
                              ),
                            ),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                labour.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${labour.role} • Rs ${labour.dailyWage.toStringAsFixed(0)} / day',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (value) async {
                                            if (value == 'edit') {
                                              try {
                                                await _showLabourDialog(
                                                  this.context,
                                                  labour: labour,
                                                );
                                              } catch (_) {
                                                _showErrorSnackBar(
                                                    'Something went wrong. Please try again.');
                                              }
                                            }
                                            if (value == 'delete' && mounted) {
                                              try {
                                                await data
                                                    .deleteLabour(labour.id);
                                              } catch (_) {
                                                _showErrorSnackBar(
                                                    'Something went wrong. Please try again.');
                                              }
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Delete'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            labour.phoneNumber,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.currency_rupee,
                                                size: 18,
                                                color: AppColors.absent,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Advance Rs ${labour.advanceAmount.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.absent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 8,
                                              ),
                                            ),
                                            onPressed: () async {
                                              try {
                                                await _showAdvanceDialog(
                                                    this.context, labour);
                                              } catch (_) {
                                                _showErrorSnackBar(
                                                    'Something went wrong. Please try again.');
                                              }
                                            },
                                            icon:
                                                const Icon(Icons.add, size: 16),
                                            label: const Text('Advance'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAdvanceDialog(BuildContext context, Labour labour) async {
    final provider = context.read<SiteDataProvider>();
    final amountController = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Add Advance - ${labour.name}'),
          content: TextField(
            controller: amountController,
            decoration: const InputDecoration(labelText: 'Advance Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0) {
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(false);
                  }
                  return;
                }

                try {
                  await provider.addAdvancePayment(
                    labourId: labour.id,
                    amount: amount,
                  );
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content:
                              Text('Something went wrong. Please try again.'),
                        ),
                      );
                  }
                  return;
                }

                if (ctx.mounted) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showLabourDialog(BuildContext context, {Labour? labour}) async {
    final provider = context.read<SiteDataProvider>();
    final nameController = TextEditingController(text: labour?.name ?? '');
    final roleController = TextEditingController(text: labour?.role ?? '');
    final wageController = TextEditingController(
      text: labour?.dailyWage.toStringAsFixed(0) ?? '',
    );
    final phoneController =
        TextEditingController(text: labour?.phoneNumber ?? '');
    final advanceController = TextEditingController(
      text: labour?.advanceAmount.toStringAsFixed(0) ?? '0',
    );
    final extraHoursController = TextEditingController(
      text: labour?.extraHours.toStringAsFixed(1) ?? '0',
    );
    final overtimeRateController = TextEditingController(
      text: labour?.overtimeRate.toStringAsFixed(0) ?? '0',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            labour == null ? 'Add Labour' : 'Edit Labour',
            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          contentPadding: const EdgeInsets.all(16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LabourDialogInputField(
                  controller: nameController,
                  label: 'Name',
                  prefixIcon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                _LabourDialogInputField(
                  controller: roleController,
                  label: 'Role',
                  prefixIcon: Icons.work_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                _LabourDialogInputField(
                  controller: wageController,
                  label: 'Daily Wage',
                  prefixIcon: Icons.currency_rupee,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _LabourDialogInputField(
                  controller: phoneController,
                  label: 'Phone Number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _LabourDialogInputField(
                  controller: advanceController,
                  label: 'Advance Amount',
                  prefixIcon: Icons.account_balance_wallet_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _LabourDialogInputField(
                  controller: extraHoursController,
                  label: 'Extra Hours',
                  prefixIcon: Icons.more_time_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 14),
                _LabourDialogInputField(
                  controller: overtimeRateController,
                  label: 'Overtime Rate (Rs/hr)',
                  prefixIcon: Icons.currency_rupee,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final wage = double.tryParse(wageController.text.trim()) ?? 0;
                final advance =
                    double.tryParse(advanceController.text.trim()) ?? 0;
                final extraHours =
                    double.tryParse(extraHoursController.text.trim()) ?? 0;
                final overtimeRate =
                    double.tryParse(overtimeRateController.text.trim()) ?? 0;

                if (nameController.text.trim().isEmpty ||
                    roleController.text.trim().isEmpty) {
                  return;
                }

                if (wage < 0 ||
                    advance < 0 ||
                    extraHours < 0 ||
                    overtimeRate < 0) {
                  ScaffoldMessenger.of(ctx)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Values cannot be negative.'),
                      ),
                    );
                  return;
                }

                try {
                  if (labour == null) {
                    await provider.addLabour(
                      name: nameController.text.trim(),
                      role: roleController.text.trim(),
                      dailyWage: wage,
                      phoneNumber: phoneController.text.trim(),
                      advanceAmount: advance,
                      extraHours: extraHours,
                      overtimeRate: overtimeRate,
                    );
                  } else {
                    await provider.updateLabour(
                      labour.copyWith(
                        name: nameController.text.trim(),
                        role: roleController.text.trim(),
                        dailyWage: wage,
                        phoneNumber: phoneController.text.trim(),
                        advanceAmount: advance,
                        extraHours: extraHours,
                        overtimeRate: overtimeRate,
                      ),
                    );
                  }
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content:
                              Text('Something went wrong. Please try again.'),
                        ),
                      );
                  }
                  return;
                }

                if (ctx.mounted) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    return saved ?? false;
  }
}

class _LabourDialogInputField extends StatelessWidget {
  const _LabourDialogInputField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}
