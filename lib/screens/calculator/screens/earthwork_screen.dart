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

class EarthworkScreen extends StatefulWidget {
  const EarthworkScreen({super.key});

  @override
  State<EarthworkScreen> createState() => _EarthworkScreenState();
}

class _EarthworkScreenState extends State<EarthworkScreen> {
  final _lenCtrl = TextEditingController(text: '10');
  final _widCtrl = TextEditingController(text: '10');
  final _depCtrl = TextEditingController(text: '5');
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadLastValues();
  }

  @override
  void dispose() {
    _saveLastValues();
    _lenCtrl.dispose();
    _widCtrl.dispose();
    _depCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lenCtrl.text = prefs.getString('calc_earth_len') ?? '10';
      _widCtrl.text = prefs.getString('calc_earth_wid') ?? '10';
      _depCtrl.text = prefs.getString('calc_earth_dep') ?? '5';
    });
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
        title: const Text('Earthwork', style: CalcTextStyles.screenTitle),
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
                    icon: Icons.terrain_rounded,
                    title: 'Excavation Calculator',
                    description: 'Calculate soil volume and trucks',
                    iconColor: CalcColors.earthwork,
                    iconBg: CalcColors.earthworkBg,
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
            CalcButton(label: 'CALCULATE', color: CalcColors.earthwork, onPressed: _calculate),
            if (_result != null)
              ResultCard(
                mainValue: '${_result!['m3']} m³',
                mainLabel: 'Total Excavated Volume (${_result!['cft']} cft)',
                rows: [
                  ResultRowData('Swell Volume (Loose)', '${_result!['swellM3']} m³'),
                  ResultRowData('Est. Trucks (5m³)', '${_result!['trucks']}'),
                  ResultRowData('Backfill Needed (~75%)', '${_result!['backfillM3']} m³'),
                ],
                type: ResultType.neutral,
                noteText: '* Assumes 30% soil swell factor',
              ),
          ],
        ),
      ),
    );
  }
}
