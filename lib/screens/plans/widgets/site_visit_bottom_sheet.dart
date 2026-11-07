import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../models/house_plan_model.dart';
import '../../../providers/house_plans_provider.dart';
import '../../../services/session_service.dart';

class SiteVisitBottomSheet extends StatefulWidget {
  final HousePlanOwner owner;
  final HousePlansProvider provider;

  const SiteVisitBottomSheet({
    super.key,
    required this.owner,
    required this.provider,
  });

  static Future<void> show(
    BuildContext context, {
    required HousePlanOwner owner,
    required HousePlansProvider provider,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SiteVisitBottomSheet(owner: owner, provider: provider),
    );
  }

  @override
  State<SiteVisitBottomSheet> createState() => _SiteVisitBottomSheetState();
}

class _SiteVisitBottomSheetState extends State<SiteVisitBottomSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _purposeCtrl;
  late final TextEditingController _notesCtrl;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final List<String> _quickPurposes = [
    'Plinth Level',
    'Column Alignment',
    'Footing & Rebar',
    'Slab Casting',
    'Site Consultation',
    'Final Inspection',
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '1500');
    _purposeCtrl = TextEditingController(text: 'Site Consultation');
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticUtils.light();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid visit amount')),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticUtils.select();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final newVisit = HouseSiteVisit(
        id: 'visit_${DateTime.now().millisecondsSinceEpoch}',
        date: dateStr,
        amount: amount,
        purpose: _purposeCtrl.text.trim().isNotEmpty ? _purposeCtrl.text.trim() : 'Site Consultation',
        notes: _notesCtrl.text.trim(),
        recordedAt: DateTime.now().toIso8601String(),
      );

      await widget.provider.addSiteVisit(
        ownerId: widget.owner.id,
        visit: newVisit,
      );

      if (mounted) {
        Navigator.pop(context);
        final isSupervisor = SessionService.instance.role == 'supervisor';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.successColor(context),
            content: Text(
              isSupervisor
                  ? '✓ Site visit logged (₹${amount.round()}) • Sent for Admin Verification'
                  : '✓ Site visit recorded (₹${amount.round()}) for ${widget.owner.ownerName}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving visit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = AppColors.surfaceColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textMuted = AppColors.mutedTextColor(context);
    final border = AppColors.borderColor(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Site Visit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Client: ${widget.owner.ownerName}',
                          style: TextStyle(fontSize: 12, color: textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount field
              Text(
                'VISIT CHARGE (RS)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor(context)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                ),
              ),
              const SizedBox(height: 16),

              // Date picker
              Text(
                'VISIT DATE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryColor(context)),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                        ],
                      ),
                      Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor(context))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Purpose Chips
              Text(
                'PURPOSE / STAGE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickPurposes.map((p) {
                  final isSelected = _purposeCtrl.text == p;
                  return ChoiceChip(
                    label: Text(p, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.black : textPrimary)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryColor(context),
                    backgroundColor: isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF1F5F9),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _purposeCtrl.text = p);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _purposeCtrl,
                decoration: InputDecoration(
                  hintText: 'Or enter custom purpose...',
                  hintStyle: TextStyle(fontSize: 13, color: textMuted),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                ),
              ),
              const SizedBox(height: 16),

              // Remarks text
              Text(
                'ENGINEER REMARKS (OPTIONAL)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g., Checked column alignment and footing 2 casting details...',
                  hintStyle: TextStyle(fontSize: 12, color: textMuted),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F1A2A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check_circle_rounded, color: Colors.black),
                  label: Text(
                    _isSaving ? 'Recording Visit...' : 'Save Site Visit',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
