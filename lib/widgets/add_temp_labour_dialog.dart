import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';

class AddTempLabourDialog extends StatefulWidget {
  const AddTempLabourDialog({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.onAdded,
  });

  final String siteId;
  final String siteName;
  final Function(String labourId) onAdded;

  @override
  State<AddTempLabourDialog> createState() => _AddTempLabourDialogState();
}

class _AddTempLabourDialogState extends State<AddTempLabourDialog> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _wageCtrl  = TextEditingController();
  final _skillCtrl = TextEditingController();
  bool _saving     = false;
  String? _error;

  InputDecoration _inputDeco(String label, String hint, IconData icon, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB);
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE5E7EB);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9333EA)),
      filled: true,
      fillColor: fillColor,
      labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64809E), fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : const Color(0xFF9CA3AF)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF9333EA), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9333EA), Color(0xFF7E22CE)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: const Color(0xFF9333EA).withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text('Add Temp Labour',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF132B4F)))),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Site badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B))),
            child: Row(children: [
              const Icon(Icons.location_on,
                size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Site: ${widget.siteName}',
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFFD97706)))),
              const Text('Today Only',
                style: TextStyle(
                  fontSize: 10, color: Color(0xFFD97706))),
            ]),
          ),

          // Name (required)
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: _inputDeco('Full Name *', 'e.g. Ramesh Patel', Icons.person_outline, context),
          ),
          const SizedBox(height: 12),

          // Phone (optional)
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: _inputDeco('Phone (optional)', '10 digit number', Icons.phone_outlined, context).copyWith(counterText: ''),
          ),
          const SizedBox(height: 12),

          // Daily Wage (required)
          TextField(
            controller: _wageCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: _inputDeco('Daily Wage (₹) *', 'e.g. 400', Icons.currency_rupee, context),
          ),
          const SizedBox(height: 12),

          // Skill / Role (optional)
          TextField(
            controller: _skillCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: _inputDeco('Skill / Role (optional)', 'e.g. Mason, Helper, Electrician', Icons.construction, context),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 8),
          const Text(
            '⚠ Temp labour auto-hides after today\'s work is complete.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64809E)),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600))),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9333EA), Color(0xFF7E22CE)], // Premium Purple Gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : const Text('Add & Mark Present', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final wage  = double.tryParse(_wageCtrl.text.trim());

    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (wage == null || wage <= 0) {
      setState(() => _error = 'Enter valid daily wage');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';

      // Create temp labour in Firestore
      final ref = await FirebaseFirestore.instance
          .collection('labours')
          .add({
        'name':              name,
        'phone':             _phoneCtrl.text.trim().isEmpty
                                ? '' : _phoneCtrl.text.trim(),
        'skill':             _skillCtrl.text.trim(),
        'dailyWage':         wage,
        'type':              'temporary',
        'addedDate':         dateStr,
        'autoDeleteAfter':   dateStr,  // deactivate after today
        'supervisorId':      uid,
        'contractorId':      SessionService.instance.contractorId ?? uid,
        'siteId':            widget.siteId,
        'siteName':          widget.siteName,
        'isActive':          true,
        'isSynced':          true,
        'createdAt':         FieldValue.serverTimestamp(),
        'syncedAt':          FieldValue.serverTimestamp(),
      });
      await ref.update({'id': ref.id});

      // Auto-mark present at this site
      final attRef = await FirebaseFirestore.instance
          .collection('attendance')
          .add({
        'id':               '',
        'labourId':         ref.id,
        'supervisorId':     uid,
        'contractorId':     SessionService.instance.contractorId ?? uid,
        'siteId':           widget.siteId,
        'siteName':         widget.siteName,
        'date':             dateStr,
        'status':           'present',
        'shiftFactor':      1.0,
        'shiftLabel':       'full',
        'overtimeHours':    0,
        'dailyWageSnapshot': wage,
        'isSynced':         true,
        'markedVia':        'temp_labour_add',
        'syncedAt':         FieldValue.serverTimestamp(),
      });
      await attRef.update({'id': attRef.id});

      widget.onAdded(ref.id);
      if (mounted) Navigator.pop(context);

    } catch (e) {
      setState(() {
        _error = 'Failed to add: $e';
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _wageCtrl.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }
}
