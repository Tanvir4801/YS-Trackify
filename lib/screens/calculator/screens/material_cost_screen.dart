import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../utils/calc_constants.dart';
import '../models/calc_history_item.dart';
import '../services/calc_history_service.dart';
import '../widgets/calc_result_widgets.dart';
import 'package:uuid/uuid.dart';

class MaterialCostScreen extends StatefulWidget {
  final Map<String, dynamic>? initialInputs;
  const MaterialCostScreen({super.key, this.initialInputs});

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
  bool _isCalculated = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialInputs != null) {
      _cementQtyCtrl.text = widget.initialInputs!['cq']?.toString() ?? '';
      _cementRateCtrl.text = widget.initialInputs!['cr']?.toString() ?? '';
      _sandQtyCtrl.text = widget.initialInputs!['sq']?.toString() ?? '';
      _sandRateCtrl.text = widget.initialInputs!['sr']?.toString() ?? '';
      _aggQtyCtrl.text = widget.initialInputs!['aq']?.toString() ?? '';
      _aggRateCtrl.text = widget.initialInputs!['ar']?.toString() ?? '';
      _steelQtyCtrl.text = widget.initialInputs!['stq']?.toString() ?? '';
      _steelRateCtrl.text = widget.initialInputs!['str']?.toString() ?? '';
    }
  }

  void _calculate() {
    final cq = double.tryParse(_cementQtyCtrl.text) ?? 0;
    final cr = double.tryParse(_cementRateCtrl.text) ?? 0;
    
    final sq = double.tryParse(_sandQtyCtrl.text) ?? 0;
    final sr = double.tryParse(_sandRateCtrl.text) ?? 0;
    
    final aq = double.tryParse(_aggQtyCtrl.text) ?? 0;
    final ar = double.tryParse(_aggRateCtrl.text) ?? 0;
    
    final stq = double.tryParse(_steelQtyCtrl.text) ?? 0;
    final str = double.tryParse(_steelRateCtrl.text) ?? 0;

    final total = (cq * cr) + (sq * sr) + (aq * ar) + (stq * str);

    setState(() {
      _totalCost = total;
      _isCalculated = true;
    });

    final item = CalcHistoryItem(
      id: const Uuid().v4(),
      category: 'Material Cost',
      title: 'Total Cost: ₹${total.toStringAsFixed(2)}',
      subtitle: 'Cement, Sand, Agg, Steel',
      timestamp: DateTime.now(),
      inputs: {
        'cq': cq, 'cr': cr,
        'sq': sq, 'sr': sr,
        'aq': aq, 'ar': ar,
        'stq': stq, 'str': str,
      },
      results: {
        'mainTitle': 'Total Material Cost',
        'mainValue': '₹${total.toStringAsFixed(2)}',
        'formula': 'Sum of Qty × Rate',
        'materials': [
          {'label': 'Cement Cost', 'value': '₹${(cq * cr).toStringAsFixed(2)}'},
          {'label': 'Sand Cost', 'value': '₹${(sq * sr).toStringAsFixed(2)}'},
          {'label': 'Aggregate Cost', 'value': '₹${(aq * ar).toStringAsFixed(2)}'},
          {'label': 'Steel Cost', 'value': '₹${(stq * str).toStringAsFixed(2)}'},
        ],
      },
    );
    CalcHistoryService.save(item);
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
      backgroundColor: CalcColors.pageBg(context),
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg(context),
        elevation: 0,
        title: Text('Material Cost Estimator', style: CalcTextStyles.screenTitle(context)),
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
                backgroundColor: AppColors.primaryColor(context),
                foregroundColor: AppColors.textOnPrimaryColor(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('CALCULATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
            if (!_isCalculated)
              const CalcGuideCard(
                title: 'HOW ESTIMATION WORKS',
                steps: [
                  'Enter the required quantity for each material.',
                  'Enter the current market rate per unit.',
                  'Calculate the total estimated cost for the project.',
                ],
                formula: 'Total = ∑ (Quantity × Rate)',
              )
            else ...[
              CalcResultHeader(
                title: 'Total Material Cost',
                value: '₹${_totalCost.toStringAsFixed(2)}',
                formula: 'Cement + Sand + Agg + Steel',
              ),
              CalcDetailSection(
                details: {
                  'Cement': '₹${((double.tryParse(_cementQtyCtrl.text)??0)*(double.tryParse(_cementRateCtrl.text)??0)).toStringAsFixed(2)}',
                  'Sand': '₹${((double.tryParse(_sandQtyCtrl.text)??0)*(double.tryParse(_sandRateCtrl.text)??0)).toStringAsFixed(2)}',
                  'Aggregate': '₹${((double.tryParse(_aggQtyCtrl.text)??0)*(double.tryParse(_aggRateCtrl.text)??0)).toStringAsFixed(2)}',
                  'Steel': '₹${((double.tryParse(_steelQtyCtrl.text)??0)*(double.tryParse(_steelRateCtrl.text)??0)).toStringAsFixed(2)}',
                },
              ),
              CalcActionRow(onRecalculate: _calculate, onReset: _clear),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialInput(String label, TextEditingController qtyCtrl, TextEditingController rateCtrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalcColors.surface(context),
        borderRadius: BorderRadius.circular(CalcDimens.radiusLg),
        border: Border.all(color: CalcColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: CalcColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(qtyCtrl, 'Quantity'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(rateCtrl, 'Rate (₹)'),
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
      style: TextStyle(color: CalcColors.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: CalcColors.textSecondary(context)),
        filled: true,
        fillColor: CalcColors.inputBg(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }


}
