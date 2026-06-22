import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/labour_model.dart';

Future<void> showAdvanceDialog(BuildContext context, Labour labour) async {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  final contractorId = labour.contractorId ?? '';
  if (contractorId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error: Contractor ID missing for this labour.')),
    );
    return;
  }

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.currency_rupee, color: Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Advance — ${labour.name}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. personal work',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final amount = double.tryParse(amountCtrl.text);
            if (amount == null || amount <= 0) {
              return; // validate
            }

            // Save to Firestore advances collection (or payments based on app logic)
            // Wait, does the app use "advances" collection or "payments" collection for advances?
            // User requested to save to "advances" collection:
            await FirebaseFirestore.instance.collection('advances').add({
              'labourId': labour.id,
              'labourName': labour.name,
              'contractorId': contractorId,
              'amount': amount,
              'note': noteCtrl.text,
              'type': 'given',
              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'givenBy': currentUser.uid,
              'createdAt': FieldValue.serverTimestamp(),
            });

            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('₹${amount.toStringAsFixed(0)} advance recorded for ${labour.name}'),
                  backgroundColor: const Color(0xFFF59E0B),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
          child: const Text('Save Advance', style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}
