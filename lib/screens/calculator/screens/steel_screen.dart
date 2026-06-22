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

class SteelScreen extends StatefulWidget {
  const SteelScreen({super.key});

  @override
  State<SteelScreen> createState() => _SteelScreenState();
}

class _SteelScreenState extends State<SteelScreen> {
  final _diaCtrl = TextEditingController(text: '12');
  final _lenCtrl = TextEditingController(text: '6');
  final _nosCtrl = TextEditingController(text: '100');
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadLastValues();
  }

  @override
  void dispose() {
    _saveLastValues();
    _diaCtrl.dispose();
    _lenCtrl.dispose();
    _nosCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _diaCtrl.text = prefs.getString('calc_steel_dia') ?? '12';
      _lenCtrl.text = prefs.getString('calc_steel_len') ?? '6';
      _nosCtrl.text = prefs.getString('calc_steel_nos') ?? '100';
    });
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
    );
    CalcHistoryService.save(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalcColors.pageBg,
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg,
        elevation: 0,
        title: const Text('Steel Weight', style: CalcTextStyles.screenTitle),
        iconTheme: const IconThemeData(color: CalcColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CalcDimens.pagePadding),
        child: Column(
          children: [
            CalcCard(
              child: Column(
                children: [
                  const CalcCardHeader(
                    icon: Icons.linear_scale_rounded,
                    title: 'Bar Weight Calculator',
                    description: 'Calculate weight of rebars',
                    iconColor: CalcColors.steel,
                    iconBg: CalcColors.steelBg,
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
            CalcButton(label: 'CALCULATE', color: CalcColors.steel, onPressed: _calculate),
            if (_result != null)
              ResultCard(
                mainValue: '${_result!['totalKg']} kg',
                mainLabel: 'Total Weight | Unit: ${_result!['wpm']} kg/m',
                rows: [
                  ResultRowData('Total Length', '${_result!['totalLength']} m'),
                  ResultRowData('Approx Bundles', '${_result!['bundles']} bundles (45kg/bdl)'),
                  ResultRowData('Cost Estimate', '₹${_result!['costEst']} (@ ₹65/kg)'),
                ],
                type: ResultType.neutral,
              ),
          ],
        ),
      ),
    );
  }
}
