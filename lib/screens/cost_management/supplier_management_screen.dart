import 'package:ys_trackify/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../providers/cost_management_provider.dart';
import '../../models/supplier_model.dart';
import '../../services/session_service.dart';

class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({super.key});

  @override
  State<SupplierManagementScreen> createState() => _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _contact = '';

  void _showAddSupplierDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2438),
        title: const Text('Add Supplier', style: TextStyle(color: Colors.white)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Supplier Name', labelStyle: TextStyle(color: Colors.white70)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _name = v ?? '',
              ),
              TextFormField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Contact Number', labelStyle: TextStyle(color: Colors.white70)),
                keyboardType: TextInputType.phone,
                onSaved: (v) => _contact = v ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A437)),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                final s = SupplierModel(
                  id: const Uuid().v4(),
                  contractorId: SessionService.instance.contractorId ?? '',
                  name: _name,
                  contactNumber: _contact,
                );
                await context.read<CostManagementProvider>().addSupplier(s);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('SAVE', style: TextStyle(color: Color(0xFF10141C))),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(SupplierModel supplier) {
    final currency = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
    double payment = 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2438),
        title: Text('Pay ${supplier.name}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending: ${currency.format(supplier.pendingAmount)}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Payment Amount (₹)', labelStyle: TextStyle(color: Colors.white70)),
              onChanged: (v) => payment = double.tryParse(v) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
            onPressed: () async {
              if (payment > 0) {
                await context.read<CostManagementProvider>().recordSupplierPayment(supplier.id, payment);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('RECORD PAYMENT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final costProv = context.watch<CostManagementProvider>();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF10141C),
      appBar: AppBar(
        title: const Text('Suppliers', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A2438),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: costProv.suppliers.length,
        itemBuilder: (context, index) {
          final s = costProv.suppliers[index];
          final pending = s.pendingAmount;
          return Card(
            color: const Color(0xFF1A2438),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.payment, color: Color(0xFFD4A437)),
                        onPressed: () => _showPaymentDialog(s),
                      ),
                    ],
                  ),
                  if (s.contactNumber.isNotEmpty)
                    Text(s.contactNumber, style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatCol('Total Purchases', currency.format(s.totalPurchases), Colors.white),
                      _StatCol('Paid', currency.format(s.paidAmount), const Color(0xFF22C55E)),
                      _StatCol('Pending', currency.format(pending), pending > 0 ? AppColors.danger : Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4A437),
        onPressed: _showAddSupplierDialog,
        child: const Icon(Icons.add, color: Color(0xFF10141C)),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCol(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
