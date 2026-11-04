import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../utils/calc_constants.dart';
import '../models/calc_history_item.dart';
import '../services/calc_history_service.dart';
import '../widgets/calc_result_widgets.dart';
import 'package:uuid/uuid.dart';

class LabourCostScreen extends StatefulWidget {
  final Map<String, dynamic>? initialInputs;
  const LabourCostScreen({super.key, this.initialInputs});

  @override
  State<LabourCostScreen> createState() => _LabourCostScreenState();
}

class _LabourCostScreenState extends State<LabourCostScreen> {
  final _teamSizeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _avgWageCtrl = TextEditingController();

  double _totalCost = 0;
  bool _isCalculated = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialInputs != null) {
      _teamSizeCtrl.text = widget.initialInputs!['ts']?.toString() ?? '';
      _durationCtrl.text = widget.initialInputs!['dur']?.toString() ?? '';
      _avgWageCtrl.text = widget.initialInputs!['aw']?.toString() ?? '';
    }
  }

  void _calculate() {
    final teamSize = int.tryParse(_teamSizeCtrl.text) ?? 0;
    final duration = int.tryParse(_durationCtrl.text) ?? 0;
    final avgWage = double.tryParse(_avgWageCtrl.text) ?? 0;

    final total = teamSize * duration * avgWage;

    setState(() {
      _totalCost = total;
      _isCalculated = true;
    });

    final item = CalcHistoryItem(
      id: const Uuid().v4(),
      category: 'Labour Cost',
      title: 'Cost: ₹${total.toStringAsFixed(2)}',
      subtitle: '$teamSize persons, $duration days',
      timestamp: DateTime.now(),
      inputs: {
        'ts': teamSize,
        'dur': duration,
        'aw': avgWage,
      },
      results: {
        'mainTitle': 'Total Labour Cost',
        'mainValue': '₹${total.toStringAsFixed(2)}',
        'formula': 'Size × Days × Wage',
        'materials': [
          {'label': 'Team Size', 'value': '$teamSize persons'},
          {'label': 'Duration', 'value': '$duration days'},
          {'label': 'Average Wage', 'value': '₹${avgWage.toStringAsFixed(2)}/day'},
        ],
      },
    );
    CalcHistoryService.save(item);
  }

  void _clear() {
    _teamSizeCtrl.clear();
    _durationCtrl.clear();
    _avgWageCtrl.clear();
    setState(() => _totalCost = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalcColors.pageBg(context),
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg(context),
        elevation: 0,
        title: Text('Labour Cost Estimator', style: CalcTextStyles.screenTitle(context)),
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
            _buildInputRow('Team Size (persons)', _teamSizeCtrl, TextInputType.number),
            const SizedBox(height: 16),
            _buildInputRow('Duration (days)', _durationCtrl, TextInputType.number),
            const SizedBox(height: 16),
            _buildInputRow('Average Daily Wage (₹)', _avgWageCtrl, const TextInputType.numberWithOptions(decimal: true)),
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
                title: 'HOW LABOUR COST WORKS',
                steps: [
                  'Enter the total number of workers.',
                  'Enter the estimated duration of the work in days.',
                  'Enter the average daily wage per worker.',
                ],
                formula: 'Total = Size × Days × Wage',
              )
            else ...[
              CalcResultHeader(
                title: 'Total Labour Cost',
                value: '₹${_totalCost.toStringAsFixed(2)}',
                formula: 'Size × Days × Wage',
              ),
              CalcDetailSection(
                details: {
                  'Team Size': '${_teamSizeCtrl.text} persons',
                  'Duration': '${_durationCtrl.text} days',
                  'Average Wage': '₹${_avgWageCtrl.text} / day',
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

  Widget _buildInputRow(String label, TextEditingController ctrl, TextInputType inputType) {
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
          TextField(
            controller: ctrl,
            keyboardType: inputType,
            style: TextStyle(color: CalcColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'Enter value',
              hintStyle: TextStyle(color: CalcColors.textSecondary(context)),
              filled: true,
              fillColor: CalcColors.inputBg(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }


}
