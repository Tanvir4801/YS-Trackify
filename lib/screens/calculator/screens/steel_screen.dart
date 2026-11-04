import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/calc_constants.dart';
import '../utils/calc_formulas.dart';
import '../widgets/calc_input_field.dart';
import '../widgets/calc_button.dart';
import '../widgets/result_card.dart';
import '../widgets/calc_card.dart';
import '../models/calc_history_item.dart';
import '../services/calc_history_service.dart';
import '../widgets/calc_result_widgets.dart';

class SteelScreen extends StatefulWidget {
  final Map<String, dynamic>? initialInputs;
  const SteelScreen({super.key, this.initialInputs});

  @override
  State<SteelScreen> createState() => _SteelScreenState();
}

class _SteelScreenState extends State<SteelScreen> {
  final _diaCtrl = TextEditingController();
  final _lenCtrl = TextEditingController();
  final _nosCtrl = TextEditingController();
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialInputs != null) {
      _diaCtrl.text = widget.initialInputs!['dia']?.toString() ?? '';
      _lenCtrl.text = widget.initialInputs!['length']?.toString() ?? '';
      _nosCtrl.text = widget.initialInputs!['nos']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _saveLastValues();
    _diaCtrl.dispose();
    _lenCtrl.dispose();
    _nosCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_steel_dia', _diaCtrl.text);
    await prefs.setString('calc_steel_len', _lenCtrl.text);
    await prefs.setString('calc_steel_nos', _nosCtrl.text);
  }

  void _calculate() {
    final dia = double.tryParse(_diaCtrl.text) ?? 0;
    final len = double.tryParse(_lenCtrl.text) ?? 0;
    final nos = double.tryParse(_nosCtrl.text) ?? 0;

    if (dia <= 0 || len <= 0 || nos <= 0) return;

    final res = SteelFormulas.calculate(diaMm: dia, lengthM: len, nos: nos);
    setState(() => _result = res);

    final item = CalcHistoryItem(
      id: const Uuid().v4(),
      category: 'Steel',
      title: 'Weight: ${res['totalKg']} kg',
      subtitle: '${dia}mm dia | ${len}m x $nos',
      timestamp: DateTime.now(),
      inputs: {
        'dia': dia,
        'length': len,
        'nos': nos,
      },
      results: {
        'mainTitle': 'Total Weight',
        'mainValue': '${res['totalKg']} kg',
        'formula': 'D² / 162.28 × Length × Nos',
        'materials': [
          {'label': 'Total Length', 'value': '${res['totalLength']} m'},
          {'label': 'Approx Bundles', 'value': '${res['bundles']} (45kg/bdl)'},
          {'label': 'Cost Estimate', 'value': '₹${res['costEst']} (@ ₹65/kg)'},
        ],
      },
    );
    CalcHistoryService.save(item);
  }

  void _reset() {
    setState(() {
      _diaCtrl.clear();
      _lenCtrl.clear();
      _nosCtrl.clear();
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalcColors.pageBg(context),
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg(context),
        elevation: 0,
        title: Text('Steel Weight', style: CalcTextStyles.screenTitle(context)),
        iconTheme: IconThemeData(color: CalcColors.textPrimary(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CalcDimens.pagePadding),
        child: Column(
          children: [
            CalcCard(
              child: Column(
                children: [
                  CalcCardHeader(
                    icon: Icons.linear_scale_rounded,
                    title: 'Bar Weight Calculator',
                    description: 'Calculate weight of rebars',
                    iconColor: CalcColors.steel(context),
                    iconBg: CalcColors.steelBg(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(CalcDimens.cardPadding),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: CalcInputField(label: 'Dia (mm)', controller: _diaCtrl)),
                            const SizedBox(width: CalcDimens.fieldGap),
                            Expanded(child: CalcInputField(label: 'Length (m)', controller: _lenCtrl)),
                            const SizedBox(width: CalcDimens.fieldGap),
                            Expanded(child: CalcInputField(label: 'No. of bars', controller: _nosCtrl)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CalcButton(label: 'CALCULATE', color: CalcColors.steel(context), onPressed: _calculate),
            const SizedBox(height: 16),
            if (_result == null)
              const CalcGuideCard(
                title: 'HOW STEEL WEIGHT WORKS',
                steps: [
                  'Enter the diameter of the rebar in mm.',
                  'Enter the length of one single bar in meters.',
                  'Enter the total number of bars required.',
                ],
                formula: 'Weight = (D² / 162.28) × L',
              )
            else ...[
              CalcResultHeader(
                title: 'Total Weight',
                value: '${_result!['totalKg']} kg',
                formula: 'Unit: ${_result!['wpm']} kg/m',
              ),
              CalcMaterialTable(
                title: 'ESTIMATES',
                rows: [
                  CalcMaterialRow('Total Length', '${_result!['totalLength']} m'),
                  CalcMaterialRow('Approx Bundles', '${_result!['bundles']} (45kg/bdl)'),
                  CalcMaterialRow('Cost Estimate', '₹${_result!['costEst']} (@ ₹65/kg)'),
                ],
              ),
              CalcDetailSection(
                details: {
                  'Diameter': '${_diaCtrl.text} mm',
                  'Length per bar': '${_lenCtrl.text} m',
                  'Number of bars': _nosCtrl.text,
                },
              ),
              CalcActionRow(
                onRecalculate: _calculate,
                onReset: _reset,
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
