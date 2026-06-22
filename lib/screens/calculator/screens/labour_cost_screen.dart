import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../utils/calc_constants.dart';

class LabourCostScreen extends StatefulWidget {
  const LabourCostScreen({super.key});

  @override
  State<LabourCostScreen> createState() => _LabourCostScreenState();
}

class _LabourCostScreenState extends State<LabourCostScreen> {
  final _teamSizeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _avgWageCtrl = TextEditingController();

  double _totalCost = 0;

  void _calculate() {
    final teamSize = int.tryParse(_teamSizeCtrl.text) ?? 0;
    final duration = int.tryParse(_durationCtrl.text) ?? 0;
    final avgWage = double.tryParse(_avgWageCtrl.text) ?? 0;

    setState(() {
      _totalCost = teamSize * duration * avgWage;
    });
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
      backgroundColor: CalcColors.pageBg,
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg,
        elevation: 0,
        title: const Text('Labour Cost Estimator', style: CalcTextStyles.screenTitle),
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
            _buildInputRow('Average Daily Wage (\$)', _avgWageCtrl, const TextInputType.numberWithOptions(decimal: true)),
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
              child: const Text('Calculate Labour Cost', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
            if (_totalCost > 0) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController ctrl, TextInputType inputType) {
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
          TextField(
            controller: ctrl,
            keyboardType: inputType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter value',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.navy,
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

  Widget _buildResult() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(CalcDimens.radiusLg),
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        children: [
          const Text('Total Labour Cost', style: TextStyle(color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '\$${_totalCost.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.danger, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
