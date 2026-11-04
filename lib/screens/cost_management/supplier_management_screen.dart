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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
      filled: true,
      fillColor: isDark ? AppColors.backgroundColor(context) : const Color(0xFFF8FBFF),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryColor(context), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevatedColor(context),
        title: Text('Add Supplier', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                style: TextStyle(color: AppColors.textPrimaryColor(context)),
                decoration: inputDecoration.copyWith(labelText: 'Supplier Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _name = v ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: TextStyle(color: AppColors.textPrimaryColor(context)),
                decoration: inputDecoration.copyWith(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                onSaved: (v) => _contact = v ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: AppColors.textSecondaryColor(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor(context)),
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
            child: Text('SAVE', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF102A4C), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(SupplierModel supplier) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    double payment = 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
      filled: true,
      fillColor: isDark ? AppColors.backgroundColor(context) : const Color(0xFFF8FBFF),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryColor(context), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevatedColor(context),
        title: Text('Pay ${supplier.name}', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending: ${currency.format(supplier.pendingAmount)}', style: TextStyle(color: AppColors.textSecondaryColor(context))),
            const SizedBox(height: 16),
            TextField(
              style: TextStyle(color: AppColors.textPrimaryColor(context)),
              keyboardType: TextInputType.number,
              decoration: inputDecoration.copyWith(labelText: 'Payment Amount (₹)'),
              onChanged: (v) => payment = double.tryParse(v) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: AppColors.textSecondaryColor(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? AppColors.successColor(context) : const Color(0xFF00A878)),
            onPressed: () async {
              if (payment > 0) {
                await context.read<CostManagementProvider>().recordSupplierPayment(supplier.id, payment);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('RECORD PAYMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final costProv = context.watch<CostManagementProvider>();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: Text('Suppliers', style: TextStyle(color: AppColors.textPrimaryColor(context))),
        backgroundColor: AppColors.surfaceElevatedColor(context),
        iconTheme: IconThemeData(color: AppColors.textPrimaryColor(context)),
      ),
      body: costProv.suppliers.isEmpty 
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: costProv.suppliers.length,
              itemBuilder: (context, index) {
                final s = costProv.suppliers[index];
                final pending = s.pendingAmount;
                return Card(
                  color: AppColors.surfaceElevatedColor(context),
                  elevation: isDark ? 0 : 2,
                  shadowColor: isDark ? Colors.transparent : Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDark ? BorderSide(color: AppColors.borderColor(context)) : BorderSide.none,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.name, style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.primaryColor(context).withValues(alpha: 0.15) : const Color(0xFFFFF5D9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.payment, color: isDark ? AppColors.primaryColor(context) : const Color(0xFFD88A00)),
                                onPressed: () => _showPaymentDialog(s),
                              ),
                            )
                          ],
                        ),
                        if (s.contactNumber.isNotEmpty)
                          Text(s.contactNumber, style: TextStyle(color: AppColors.textSecondaryColor(context))),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _StatCol('Total Purchases', currency.format(s.totalPurchases), AppColors.textPrimaryColor(context)),
                            _StatCol('Paid', currency.format(s.paidAmount), isDark ? AppColors.successColor(context) : const Color(0xFF00A878)),
                            _StatCol('Pending', currency.format(pending), pending > 0 ? (isDark ? AppColors.errorColor(context) : const Color(0xFFF43F5E)) : AppColors.textPrimaryColor(context)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryColor(context),
        onPressed: _showAddSupplierDialog,
        child: Icon(Icons.add, color: isDark ? Colors.white : AppColors.textPrimaryColor(context)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryColor(context).withValues(alpha: 0.1) : const Color(0xFFFFF5D9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_alt, size: 64, color: isDark ? AppColors.primaryColor(context) : const Color(0xFFD88A00)),
          ),
          const SizedBox(height: 24),
          Text(
            'No suppliers yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add suppliers to track purchases\nand payments.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
        ],
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
        Text(label, style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
