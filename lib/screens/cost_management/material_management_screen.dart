import 'dart:io';
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

    setState(() => _isAdding = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final costProv = context.watch<CostManagementProvider>();
    final sitesProv = context.watch<SitesProvider>();
    final suppliers = costProv.suppliers;

    return Scaffold(
      backgroundColor: const Color(0xFF10141C),
      appBar: AppBar(
        title: const Text('Material Management', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A2438),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: costProv.isLoading && costProv.materialPurchases.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4A437)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: costProv.materialPurchases.length,
              itemBuilder: (context, index) {
                final p = costProv.materialPurchases[index];
                return Card(
                  color: const Color(0xFF1A2438),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('${p.materialName} (${p.category})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('${p.quantity} ${p.unit} @ ₹${p.pricePerUnit} = ₹${p.totalAmount}\nSupplier: ${p.supplierName.isNotEmpty ? p.supplierName : 'N/A'}\nDate: ${p.purchaseDate}', style: const TextStyle(color: Colors.white70)),
                    trailing: p.billUrl.isNotEmpty 
                        ? const Icon(Icons.receipt, color: Color(0xFFD4A437))
                        : null,
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4A437),
        onPressed: () => _showAddDialog(context, sitesProv.sites, suppliers),
        child: const Icon(Icons.add, color: Color(0xFF10141C)),
      ),
    );
  }

  void _showAddDialog(BuildContext context, List<dynamic> sites, List<SupplierModel> suppliers) {
    _selectedImage = null;
    _purchaseDate = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2438),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16, right: 16, top: 24,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Add Material Purchase', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (sites.isNotEmpty)
                        DropdownButtonFormField(
                          dropdownColor: const Color(0xFF1A2438),
                          initialValue: _selectedSiteId ?? sites.first.id,
                          items: sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(color: Colors.white)))).toList(),
                          onChanged: (v) => setModalState(() => _selectedSiteId = v.toString()),
                          decoration: const InputDecoration(labelText: 'Site', labelStyle: TextStyle(color: Colors.white70)),
                        ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField(
                        dropdownColor: const Color(0xFF1A2438),
                        initialValue: _category,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (v) => setModalState(() => _category = v.toString()),
                        decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Material Name', labelStyle: TextStyle(color: Colors.white70)),
                        onSaved: (v) => _materialName = v ?? '',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: 'Quantity', labelStyle: TextStyle(color: Colors.white70)),
                              keyboardType: TextInputType.number,
                              onSaved: (v) => _quantity = double.tryParse(v ?? '0') ?? 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField(
                              dropdownColor: const Color(0xFF1A2438),
                              initialValue: _unit,
                              items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(color: Colors.white)))).toList(),
                              onChanged: (v) => setModalState(() => _unit = v.toString()),
                              decoration: const InputDecoration(labelText: 'Unit', labelStyle: TextStyle(color: Colors.white70)),
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Price per Unit (₹)', labelStyle: TextStyle(color: Colors.white70)),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => _pricePerUnit = double.tryParse(v ?? '0') ?? 0,
                      ),
                      DropdownButtonFormField(
                        dropdownColor: const Color(0xFF1A2438),
                        initialValue: _supplierId.isEmpty ? null : _supplierId,
                        hint: const Text('Select Supplier (Optional)', style: TextStyle(color: Colors.white70)),
                        items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (v) {
                          final s = suppliers.firstWhere((sup) => sup.id == v);
                          setModalState(() {
                            _supplierId = s.id;
                            _supplierName = s.name;
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Supplier', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.calendar_month, color: Color(0xFFD4A437)),
                              label: Text('Date: ${DateFormat('yyyy-MM-dd').format(_purchaseDate)}'),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _purchaseDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
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
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A437)),
                              icon: const Icon(Icons.camera_alt, color: Color(0xFF10141C)),
                              label: Text(_selectedImage == null ? 'Attach Bill' : 'Bill Attached', style: const TextStyle(color: Color(0xFF10141C))),
                              onPressed: () async {
                                await _pickImage();
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: _isAdding ? null : () async {
                            setModalState(() => _isAdding = true);
                            await _savePurchase();
                            if (mounted) Navigator.pop(ctx);
                          },
                          child: _isAdding 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SAVE PURCHASE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
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
