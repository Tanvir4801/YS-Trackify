import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';
import '../widgets/calc_input_field.dart';
import '../widgets/calc_select_field.dart';
import '../widgets/calc_card.dart';
import '../widgets/calc_result_widgets.dart';

class ConverterScreen extends StatefulWidget {
  final Map<String, dynamic>? initialInputs;
  const ConverterScreen({super.key, this.initialInputs});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final _valCtrl = TextEditingController();
  String _fromUnit = 'Meter';
  String _toUnit = 'Feet';

  @override
  void initState() {
    super.initState();
    if (widget.initialInputs != null) {
      _valCtrl.text = widget.initialInputs!['val']?.toString() ?? '';
      _fromUnit = widget.initialInputs!['from']?.toString() ?? 'Meter';
      _toUnit = widget.initialInputs!['to']?.toString() ?? 'Feet';
    }
  }

  final List<String> _units = ['Meter', 'Feet', 'Inches', 'Centimeter', 'Millimeter'];
  
  final Map<String, double> _toMeters = {
    'Meter': 1.0,
    'Feet': 0.3048,
    'Inches': 0.0254,
    'Centimeter': 0.01,
    'Millimeter': 0.001,
  };

  @override
  void dispose() {
    _valCtrl.dispose();
    super.dispose();
  }

  double _convert() {
    final val = double.tryParse(_valCtrl.text) ?? 0;
    final inMeters = val * _toMeters[_fromUnit]!;
    return inMeters / _toMeters[_toUnit]!;
  }

  @override
  Widget build(BuildContext context) {
    final result = _convert();

    return Scaffold(
      backgroundColor: CalcColors.pageBg(context),
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg(context),
        elevation: 0,
        title: Text('Converter', style: CalcTextStyles.screenTitle(context)),
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
                    icon: Icons.swap_horiz_rounded,
                    title: 'Unit Converter',
                    description: 'Convert length units easily',
                    iconColor: CalcColors.converter(context),
                    iconBg: CalcColors.converterBg(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(CalcDimens.cardPadding),
                    child: Column(
                      children: [
                        CalcInputField(
                          label: 'Value',
                          controller: _valCtrl,
                          onChanged: (v) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CalcSelectField(
                                label: 'From',
                                value: _fromUnit,
                                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                onChanged: (v) { if (v != null) setState(() => _fromUnit = v); },
                              ),
                            ),
                            const SizedBox(width: CalcDimens.fieldGap),
                            Expanded(
                              child: CalcSelectField(
                                label: 'To',
                                value: _toUnit,
                                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                onChanged: (v) { if (v != null) setState(() => _toUnit = v); },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_valCtrl.text.isEmpty || (double.tryParse(_valCtrl.text) ?? 0) <= 0)
              const CalcGuideCard(
                title: 'UNIT CONVERTER',
                steps: [
                  'Enter the value to convert.',
                  'Select the source unit.',
                  'Select the target unit.',
                ],
                formula: 'Result updates automatically',
              )
            else ...[
              CalcResultHeader(
                title: 'Converted Value',
                value: '${_convert().toStringAsFixed(4)} $_toUnit',
                formula: '1 $_fromUnit = ${(_toMeters[_fromUnit]! / _toMeters[_toUnit]!).toStringAsFixed(4)} $_toUnit',
              ),
              CalcDetailSection(
                details: {
                  'Input Value': '${_valCtrl.text} $_fromUnit',
                  'Conversion': '$_fromUnit ➔ $_toUnit',
                },
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
