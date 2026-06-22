import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/calc_constants.dart';
import '../utils/calc_formulas.dart';
import '../widgets/calc_input_field.dart';
import '../widgets/calc_select_field.dart';
import '../widgets/calc_button.dart';
import '../widgets/result_card.dart';
import '../widgets/calc_card.dart';
import '../models/calc_history_item.dart';
import '../services/calc_history_service.dart';

class ConcreteScreen extends StatefulWidget {
  const ConcreteScreen({super.key});

  @override
  State<ConcreteScreen> createState() => _ConcreteScreenState();
}

class _ConcreteScreenState extends State<ConcreteScreen> {
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _depthCtrl = TextEditingController();
  String _mixRatio = '1:1.5:3';
  Map<String, dynamic>? _result;

  final List<DropdownMenuItem<String>> _mixOptions = const [
    DropdownMenuItem(value: '1:1:2', child: Text('M25 (1:1:2)')),
    DropdownMenuItem(value: '1:1.5:3', child: Text('M20 (1:1.5:3)')),
    DropdownMenuItem(value: '1:2:4', child: Text('M15 (1:2:4)')),
    DropdownMenuItem(value: '1:3:6', child: Text('M10 (1:3:6)')),
  ];

  @override
  void initState() {
    super.initState();
    _loadLastValues();
  }

  @override
  void dispose() {
    _saveLastValues();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _depthCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lengthCtrl.text = prefs.getString('calc_conc_len') ?? '';
      _widthCtrl.text = prefs.getString('calc_conc_wid') ?? '';
      _depthCtrl.text = prefs.getString('calc_conc_dep') ?? '';
      _mixRatio = prefs.getString('calc_conc_mix') ?? '1:1.5:3';
    });
  }

  Future<void> _saveLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_conc_len', _lengthCtrl.text);
    await prefs.setString('calc_conc_wid', _widthCtrl.text);
    await prefs.setString('calc_conc_dep', _depthCtrl.text);
    await prefs.setString('calc_conc_mix', _mixRatio);
  }

  void _calculate() {
    final length = double.tryParse(_lengthCtrl.text) ?? 0;
    final width = double.tryParse(_widthCtrl.text) ?? 0;
    final depth = double.tryParse(_depthCtrl.text) ?? 0;

    if (length <= 0 || width <= 0 || depth <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid dimensions')),
      );
      return;
    }

    final result = ConcreteFormulas.calculate(
      lengthFt: length,
      widthFt: width,
      depthFt: depth,
      mixRatio: _mixRatio,
    );

    setState(() {
      _result = result;
    });

    final item = CalcHistoryItem(
      id: const Uuid().v4(),
      category: 'Concrete',
      title: 'Volume: ${result['wetM3']} m³',
      subtitle: '${length}x${width}x$depth ft | Mix: $_mixRatio',
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
        title: const Text('Concrete', style: CalcTextStyles.screenTitle),
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
                    icon: Icons.domain_rounded,
                    title: 'Concrete Quantity',
                    description: 'Calculate materials needed for concrete',
                    iconColor: CalcColors.concrete,
                    iconBg: CalcColors.concreteBg,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(CalcDimens.cardPadding),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: CalcInputField(label: 'Length (ft)', controller: _lengthCtrl)),
                            const SizedBox(width: CalcDimens.fieldGap),
                            Expanded(child: CalcInputField(label: 'Width (ft)', controller: _widthCtrl)),
                            const SizedBox(width: CalcDimens.fieldGap),
                            Expanded(child: CalcInputField(label: 'Depth (ft)', controller: _depthCtrl)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CalcSelectField(
                          label: 'Mix Ratio',
                          value: _mixRatio,
                          items: _mixOptions,
                          onChanged: (val) {
                            if (val != null) setState(() => _mixRatio = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CalcButton(label: 'CALCULATE', onPressed: _calculate),
            if (_result != null)
              ResultCard(
                mainValue: '${_result!['wetM3']} m³',
                mainLabel: 'Wet Volume | Area: ${_result!['areaSqFt']} sq ft',
                rows: [
                  ResultRowData('Cement Bags', '${_result!['cementBags']} bags (${_result!['cementKg']} kg)'),
                  ResultRowData('Sand (Fine Agg)', '${_result!['sandCft']} cft (${_result!['sandM3']} m³)'),
                  ResultRowData('Coarse Agg', '${_result!['aggCft']} cft (${_result!['aggM3']} m³)'),
                  ResultRowData('Water', '${_result!['waterL']} Liters'),
                ],
                noteText: '* Assumes 50kg cement bags and 1.54 dry volume factor',
                type: ResultType.neutral,
              ),
          ],
        ),
      ),
    );
  }
}
