import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../providers/cost_management_provider.dart';
import '../../providers/sites_provider.dart';
import '../../models/material_purchase_model.dart';
import '../../models/supplier_model.dart';
import '../../services/storage_service.dart';
import '../../services/session_service.dart';
import '../../core/theme/app_colors.dart';

class MaterialManagementScreen extends StatefulWidget {
  final String? siteId;
  const MaterialManagementScreen({super.key, this.siteId});

  @override
  State<MaterialManagementScreen> createState() => _MaterialManagementScreenState();
}

class _MaterialManagementScreenState extends State<MaterialManagementScreen> {
  bool _isAdding = false;
  File? _selectedImage;
  final _formKey = GlobalKey<FormState>();

  String? _selectedSiteId;
  String _materialName = '';
  String _category = 'Cement';
  double _quantity = 0;
  String _unit = 'Bag';
  double _pricePerUnit = 0;
  String _supplierId = '';
  String _supplierName = '';
  final String _invoiceNumber = '';
  DateTime _purchaseDate = DateTime.now();
  final String _remarks = '';

  final List<String> _categories = ['Cement', 'Sand', 'Steel', 'Bricks', 'Tiles', 'Paint', 'Aggregate', 'Pipe', 'Others'];
  final List<String> _units = ['Bag', 'Brass', 'KG', 'Pieces', 'Box', 'Litre', 'Ton'];

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.siteId;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isAdding = true);

    String billUrl = '';
    if (_selectedImage != null) {
      final url = await StorageService.instance.uploadFile(
        _selectedImage!,
        'bills/materials',
      );
      billUrl = url ?? '';
    }

    // Guard: widget may have been disposed during the image upload.
    if (!mounted) return;

    final sitesProv = context.read<SitesProvider>();

    final purchase = MaterialPurchaseModel(
      id: const Uuid().v4(),
      siteId: _selectedSiteId ?? (sitesProv.sites.isNotEmpty ? sitesProv.sites.first.id : ''),
      contractorId: SessionService.instance.contractorId ?? '',
      materialName: _materialName,
      category: _category,
      quantity: _quantity,
      unit: _unit,
      pricePerUnit: _pricePerUnit,
      totalAmount: _quantity * _pricePerUnit,
      supplierId: _supplierId,
      supplierName: _supplierName,
      invoiceNumber: _invoiceNumber,
      purchaseDate: DateFormat('yyyy-MM-dd').format(_purchaseDate),
      billUrl: billUrl,
      remarks: _remarks,
    );

    final success = await context.read<CostManagementProvider>().addMaterialPurchase(purchase);

    // Guard: widget may have been disposed during addMaterialPurchase.
    if (!mounted) return;

    setState(() => _isAdding = false);

    if (success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final costProv = context.watch<CostManagementProvider>();
    final sitesProv = context.watch<SitesProvider>();
    final suppliers = costProv.suppliers;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: Text('Material Management', style: TextStyle(color: AppColors.textPrimaryColor(context))),
        backgroundColor: AppColors.surfaceElevatedColor(context),
        iconTheme: IconThemeData(color: AppColors.textPrimaryColor(context)),
      ),
      body: costProv.isLoading && costProv.materialPurchases.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context)))
          : costProv.materialPurchases.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: costProv.materialPurchases.length,
                  itemBuilder: (context, index) {
                    final p = costProv.materialPurchases[index];
                    return Card(
                      color: AppColors.surfaceElevatedColor(context),
                      elevation: isDark ? 0 : 2,
                      shadowColor: isDark ? Colors.transparent : Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isDark ? BorderSide(color: AppColors.borderColor(context)) : BorderSide.none,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text('${p.materialName} (${p.category})', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold)),
                        subtitle: Text('${p.quantity} ${p.unit} @ ₹${p.pricePerUnit} = ₹${p.totalAmount}\nSupplier: ${p.supplierName.isNotEmpty ? p.supplierName : 'N/A'}\nDate: ${p.purchaseDate}', style: TextStyle(color: AppColors.textSecondaryColor(context))),
                        trailing: p.billUrl.isNotEmpty 
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor(context).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.receipt, color: AppColors.primaryColor(context), size: 20)
                              )
                            : null,
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryColor(context),
        onPressed: () => _showAddDialog(context, sitesProv.sites, suppliers),
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
              color: isDark ? AppColors.infoColor(context).withValues(alpha: 0.1) : const Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, size: 64, color: isDark ? AppColors.infoColor(context) : const Color(0xFF3B82F6)),
          ),
          const SizedBox(height: 24),
          Text(
            'No material purchases yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking material purchases\nfor this site.',
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

  void _showAddDialog(BuildContext context, List<dynamic> sites, List<SupplierModel> suppliers) {
    _selectedImage = null;
    _purchaseDate = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevatedColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20, right: 20, top: 24,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderColor(context), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      Text('Add Material Purchase', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      if (sites.isNotEmpty)
                        DropdownButtonFormField(
                          dropdownColor: AppColors.surfaceElevatedColor(context),
                          initialValue: _selectedSiteId ?? sites.first.id,
                          items: sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: TextStyle(color: AppColors.textPrimaryColor(context))))).toList(),
                          onChanged: (v) => setModalState(() => _selectedSiteId = v.toString()),
                          decoration: inputDecoration.copyWith(labelText: 'Site'),
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField(
                        dropdownColor: AppColors.surfaceElevatedColor(context),
                        initialValue: _category,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: AppColors.textPrimaryColor(context))))).toList(),
                        onChanged: (v) => setModalState(() => _category = v.toString()),
                        decoration: inputDecoration.copyWith(labelText: 'Category'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        style: TextStyle(color: AppColors.textPrimaryColor(context)),
                        decoration: inputDecoration.copyWith(labelText: 'Material Name'),
                        onSaved: (v) => _materialName = v ?? '',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              style: TextStyle(color: AppColors.textPrimaryColor(context)),
                              decoration: inputDecoration.copyWith(labelText: 'Quantity'),
                              keyboardType: TextInputType.number,
                              onSaved: (v) => _quantity = double.tryParse(v ?? '0') ?? 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField(
                              dropdownColor: AppColors.surfaceElevatedColor(context),
                              initialValue: _unit,
                              items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: TextStyle(color: AppColors.textPrimaryColor(context))))).toList(),
                              onChanged: (v) => setModalState(() => _unit = v.toString()),
                              decoration: inputDecoration.copyWith(labelText: 'Unit'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        style: TextStyle(color: AppColors.textPrimaryColor(context)),
                        decoration: inputDecoration.copyWith(labelText: 'Price per Unit (₹)'),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => _pricePerUnit = double.tryParse(v ?? '0') ?? 0,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField(
                        dropdownColor: AppColors.surfaceElevatedColor(context),
                        initialValue: _supplierId.isEmpty ? null : _supplierId,
                        hint: Text('Select Supplier (Optional)', style: TextStyle(color: AppColors.textSecondaryColor(context))),
                        items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: TextStyle(color: AppColors.textPrimaryColor(context))))).toList(),
                        onChanged: (v) {
                          final s = suppliers.firstWhere((sup) => sup.id == v);
                          setModalState(() {
                            _supplierId = s.id;
                            _supplierName = s.name;
                          });
                        },
                        decoration: inputDecoration.copyWith(labelText: 'Supplier'),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.borderColor(context)),
                                foregroundColor: AppColors.textPrimaryColor(context),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.calendar_month, color: AppColors.primaryColor(context)),
                              label: Text('Date: ${DateFormat('yyyy-MM-dd').format(_purchaseDate)}'),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _purchaseDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  builder: (ctx, child) {
                                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                                    return BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                      child: Theme(
                                        data: Theme.of(ctx).copyWith(
                                          colorScheme: isDark 
                                            ? ColorScheme.dark(
                                                primary: AppColors.primaryColor(context),
                                                surface: AppColors.surfaceColor(context),
                                                onSurface: AppColors.textPrimaryColor(context),
                                              )
                                            : ColorScheme.light(
                                                primary: AppColors.primaryColor(context),
                                                surface: AppColors.surfaceColor(context),
                                                onSurface: AppColors.textPrimaryColor(context),
                                              ),
                                          dialogBackgroundColor: AppColors.surfaceColor(context),
                                        ),
                                        child: child!,
                                      ),
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    _purchaseDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppColors.primaryColor(context).withValues(alpha: 0.15) : const Color(0xFFFFF5D9),
                                foregroundColor: isDark ? AppColors.primaryColor(context) : const Color(0xFFD88A00),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.camera_alt),
                              label: Text(_selectedImage == null ? 'Attach Bill' : 'Bill Attached', style: const TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                await _pickImage();
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor(context), 
                            foregroundColor: isDark ? Colors.white : const Color(0xFF102A4C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isAdding ? null : () async {
                            setModalState(() => _isAdding = true);
                            await _savePurchase();
                            // ctx is the bottom sheet's BuildContext — check mounted
                            // via the parent state which controls disposal.
                            if (!mounted) return;
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: _isAdding 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SAVE PURCHASE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }
}
