import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../utils/calc_constants.dart';

class MaterialCostScreen extends StatefulWidget {
  const MaterialCostScreen({super.key});

  @override
  State<MaterialCostScreen> createState() => _MaterialCostScreenState();
}

class _MaterialCostScreenState extends State<MaterialCostScreen> {
  final _cementQtyCtrl = TextEditingController();
  final _cementRateCtrl = TextEditingController();
  
  final _sandQtyCtrl = TextEditingController();
  final _sandRateCtrl = TextEditingController();
  
  final _aggQtyCtrl = TextEditingController();
  final _aggRateCtrl = TextEditingController();
  
  final _steelQtyCtrl = TextEditingController();
  final _steelRateCtrl = TextEditingController();

  double _totalCost = 0;

  void _calculate() {
    final cq = double.tryParse(_cementQtyCtrl.text) ?? 0;
    final cr = double.tryParse(_cementRateCtrl.text) ?? 0;
    
    final sq = double.tryParse(_sandQtyCtrl.text) ?? 0;
    final sr = double.tryParse(_sandRateCtrl.text) ?? 0;
    
    final aq = double.tryParse(_aggQtyCtrl.text) ?? 0;
    final ar = double.tryParse(_aggRateCtrl.text) ?? 0;
    
    final stq = double.tryParse(_steelQtyCtrl.text) ?? 0;
    final str = double.tryParse(_steelRateCtrl.text) ?? 0;

    setState(() {
      _totalCost = (cq * cr) + (sq * sr) + (aq * ar) + (stq * str);
    });
  }

  void _clear() {
    _cementQtyCtrl.clear();
    _cementRateCtrl.clear();
    _sandQtyCtrl.clear();
    _sandRateCtrl.clear();
    _aggQtyCtrl.clear();
    _aggRateCtrl.clear();
    _steelQtyCtrl.clear();
    _steelRateCtrl.clear();
    setState(() => _totalCost = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalcColors.pageBg,
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg,
        elevation: 0,
        title: const Text('Material Cost Estimator', style: CalcTextStyles.screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
            onPressed: () {
              HapticFeedback.lightImpact();
              _clear();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CalcDimens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMaterialInput('Cement (Bags)', _cementQtyCtrl, _cementRateCtrl),
            const SizedBox(height: 16),
            _buildMaterialInput('Sand (cu ft)', _sandQtyCtrl, _sandRateCtrl),
            const SizedBox(height: 16),
            _buildMaterialInput('Aggregate (cu ft)', _aggQtyCtrl, _aggRateCtrl),
            const SizedBox(height: 16),
            _buildMaterialInput('Steel (kg)', _steelQtyCtrl, _steelRateCtrl),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _calculate();
                FocusScope.of(context).unfocus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Calculate Cost', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
            if (_totalCost > 0) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialInput(String label, TextEditingController qtyCtrl, TextEditingController rateCtrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(CalcDimens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(qtyCtrl, 'Quantity'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(rateCtrl, 'Rate (\$)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.navy,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildResult() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(CalcDimens.radiusLg),
        border: Border.all(color: AppColors.gold),
      ),
      child: Column(
        children: [
          const Text('Total Material Cost', style: TextStyle(color: AppColors.goldLight, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '\$${_totalCost.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.gold, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
