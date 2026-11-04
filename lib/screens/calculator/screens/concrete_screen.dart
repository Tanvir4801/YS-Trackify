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
import '../widgets/calc_result_widgets.dart';

class ConcreteScreen extends StatefulWidget {
  final Map<String, dynamic>? initialInputs;
  const ConcreteScreen({super.key, this.initialInputs});

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
    if (widget.initialInputs != null) {
      _lengthCtrl.text = widget.initialInputs!['length']?.toString() ?? '';
      _widthCtrl.text = widget.initialInputs!['width']?.toString() ?? '';
      _depthCtrl.text = widget.initialInputs!['depth']?.toString() ?? '';
      _mixRatio = widget.initialInputs!['mixRatio']?.toString() ?? '1:1.5:3';
    }
  }

  @override
  void dispose() {
    _saveLastValues();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _depthCtrl.dispose();
    super.dispose();
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
      inputs: {
        'length': length,
        'width': width,
        'depth': depth,
        'mixRatio': _mixRatio,
      },
      results: {
        'mainTitle': 'Concrete Volume',
        'mainValue': '${result['wetM3']} m³',
        'formula': 'L × W × D × (1 + Waste)',
        'materials': [
          {'label': 'Cement', 'value': '${result['cementBags']} bags (${result['cementKg']} kg)'},
          {'label': 'Sand (Fine Agg)', 'value': '${result['sandCft']} cft (${result['sandM3']} m³)'},
          {'label': 'Coarse Agg', 'value': '${result['aggCft']} cft (${result['aggM3']} m³)'},
          {'label': 'Water', 'value': '${result['waterL']} L'},
        ],
      },
    );
    CalcHistoryService.save(item);
  }

  void _reset() {
    setState(() {
      _lengthCtrl.clear();
      _widthCtrl.clear();
      _depthCtrl.clear();
      _mixRatio = '1:1.5:3';
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
        title: Text('Concrete', style: CalcTextStyles.screenTitle(context)),
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
                    icon: Icons.domain_rounded,
                    title: 'Concrete Quantity',
                    description: 'Calculate materials needed for concrete',
                    iconColor: CalcColors.concrete(context),
                    iconBg: CalcColors.concreteBg(context),
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
            const SizedBox(height: 16),
            if (_result == null)
              const CalcGuideCard(
                title: 'HOW CONCRETE WORKS',
                steps: [
                  'Enter the dimensions of your concrete slab or volume in feet.',
                  'Select a standard mix ratio based on strength requirements.',
                  'Calculate exactly how much cement, sand, and aggregate you need.',
                ],
                formula: 'Volume = Length × Width × Depth',
              )
            else ...[
              CalcResultHeader(
                title: 'Concrete Volume',
                value: '${_result!['wetM3']} m³',
                formula: 'Area: ${_result!['areaSqFt']} sq ft',
              ),
              CalcMaterialTable(
                rows: [
                  CalcMaterialRow('Cement', '${_result!['cementBags']} bags (${_result!['cementKg']} kg)'),
                  CalcMaterialRow('Sand (Fine Agg)', '${_result!['sandCft']} cft (${_result!['sandM3']} m³)'),
                  CalcMaterialRow('Coarse Agg', '${_result!['aggCft']} cft (${_result!['aggM3']} m³)'),
                  CalcMaterialRow('Water', '${_result!['waterL']} Liters'),
                ],
              ),
              CalcDetailSection(
                details: {
                  'Mix Ratio': _mixRatio,
                  'Dimensions': '${_lengthCtrl.text} × ${_widthCtrl.text} × ${_depthCtrl.text} ft',
                  'Dry Volume Factor': '1.54 (Standard)',
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
