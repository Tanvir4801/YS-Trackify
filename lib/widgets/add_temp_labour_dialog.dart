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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EEFE),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.person_add,
            color: Color(0xFFA855F7), size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('Add Temp Labour',
          style: TextStyle(fontSize: 16))),
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
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: Icon(Icons.person_outline, size: 18),
              hintText: 'e.g. Ramesh Patel',
            ),
          ),
          const SizedBox(height: 12),

          // Phone (optional)
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              prefixIcon: Icon(Icons.phone_outlined, size: 18),
              hintText: '10 digit number',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),

          // Daily Wage (required)
          TextField(
            controller: _wageCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Daily Wage (₹) *',
              prefixIcon: Icon(Icons.currency_rupee, size: 18),
              hintText: 'e.g. 400',
            ),
          ),
          const SizedBox(height: 12),

          // Skill / Role (optional)
          TextField(
            controller: _skillCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Skill / Role (optional)',
              prefixIcon: Icon(Icons.construction, size: 18),
              hintText: 'e.g. Mason, Helper, Electrician',
            ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFA855F7)),
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
              : const Text('Add & Mark Present'),
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
