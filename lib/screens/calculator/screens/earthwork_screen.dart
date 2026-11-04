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

class EarthworkScreen extends StatefulWidget {
  final Map<String, dynamic>? initialInputs;
  const EarthworkScreen({super.key, this.initialInputs});

  @override
  State<EarthworkScreen> createState() => _EarthworkScreenState();
}

class _EarthworkScreenState extends State<EarthworkScreen> {
  final _lenCtrl = TextEditingController();
  final _widCtrl = TextEditingController();
  final _depCtrl = TextEditingController();
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialInputs != null) {
      _lenCtrl.text = widget.initialInputs!['len']?.toString() ?? '';
      _widCtrl.text = widget.initialInputs!['wid']?.toString() ?? '';
      _depCtrl.text = widget.initialInputs!['dep']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _saveLastValues();
    _lenCtrl.dispose();
    _widCtrl.dispose();
    _depCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_earth_len', _lenCtrl.text);
    await prefs.setString('calc_earth_wid', _widCtrl.text);
    await prefs.setString('calc_earth_dep', _depCtrl.text);
  }

  void _calculate() {
    final len = double.tryParse(_lenCtrl.text) ?? 0;
    final wid = double.tryParse(_widCtrl.text) ?? 0;
    final dep = double.tryParse(_depCtrl.text) ?? 0;

    if (len <= 0 || wid <= 0 || dep <= 0) return;

    final res = ExcavationFormulas.calculate(lengthFt: len, widthFt: wid, depthFt: dep);
    setState(() => _result = res);

    final item = CalcHistoryItem(
      id: const Uuid().v4(),
      category: 'Earthwork',
      title: 'Excavation: ${res['m3']} m³',
      subtitle: '${len}x${wid}x$dep ft',
      timestamp: DateTime.now(),
      inputs: {
        'len': len,
        'wid': wid,
        'dep': dep,
      },
      results: {
        'mainTitle': 'Total Excavated Volume',
        'mainValue': '${res['m3']} m³',
        'formula': '${res['cft']} cft',
        'materials': [
          {'label': 'Swell Volume (Loose)', 'value': '${res['swellM3']} m³'},
          {'label': 'Est. Trucks (5m³)', 'value': '${res['trucks']}'},
          {'label': 'Backfill Needed (~75%)', 'value': '${res['backfillM3']} m³'},
        ],
      },
    );
    CalcHistoryService.save(item);
  }

  void _reset() {
    setState(() {
      _lenCtrl.clear();
      _widCtrl.clear();
      _depCtrl.clear();
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
        title: Text('Earthwork', style: CalcTextStyles.screenTitle(context)),
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
                    icon: Icons.terrain_rounded,
                    title: 'Excavation Calculator',
                    description: 'Calculate soil volume and trucks',
                    iconColor: CalcColors.earthwork(context),
                    iconBg: CalcColors.earthworkBg(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(CalcDimens.cardPadding),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: CalcInputField(label: 'Length (ft)', controller: _lenCtrl)),
                            const SizedBox(width: CalcDimens.fieldGap),
                            Expanded(child: CalcInputField(label: 'Width (ft)', controller: _widCtrl)),
                            const SizedBox(width: CalcDimens.fieldGap),
                            Expanded(child: CalcInputField(label: 'Depth (ft)', controller: _depCtrl)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CalcButton(label: 'CALCULATE', color: CalcColors.earthwork(context), onPressed: _calculate),
            const SizedBox(height: 16),
            if (_result == null)
              const CalcGuideCard(
                title: 'HOW EXCAVATION WORKS',
                steps: [
                  'Enter the length, width, and depth of the excavation.',
                  'Volume is calculated and converted to cubic meters.',
                  'Soil swell factor (30%) is applied for truck estimation.',
                ],
                formula: 'Volume = L × W × D',
              )
            else ...[
              CalcResultHeader(
                title: 'Total Excavated Volume',
                value: '${_result!['m3']} m³',
                formula: '${_result!['cft']} cft',
              ),
              CalcMaterialTable(
                title: 'ESTIMATES',
                rows: [
                  CalcMaterialRow('Swell Volume (Loose)', '${_result!['swellM3']} m³'),
                  CalcMaterialRow('Est. Trucks (5m³)', '${_result!['trucks']}'),
                  CalcMaterialRow('Backfill Needed (~75%)', '${_result!['backfillM3']} m³'),
                ],
              ),
              CalcDetailSection(
                details: {
                  'Dimensions': '${_lenCtrl.text} × ${_widCtrl.text} × ${_depCtrl.text} ft',
                  'Swell Factor': '30% (Standard)',
                  'Backfill Assumption': '75% of excavated volume',
                },
              ),
              CalcActionRow(onRecalculate: _calculate, onReset: _reset),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
