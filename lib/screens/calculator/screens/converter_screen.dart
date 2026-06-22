import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';
import '../widgets/calc_input_field.dart';
import '../widgets/calc_select_field.dart';
import '../widgets/calc_card.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final _valCtrl = TextEditingController(text: '1');
  String _fromUnit = 'Meter';
  String _toUnit = 'Feet';

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
      backgroundColor: CalcColors.pageBg,
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg,
        elevation: 0,
        title: const Text('Converter', style: CalcTextStyles.screenTitle),
        iconTheme: const IconThemeData(color: CalcColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CalcDimens.pagePadding),
        child: CalcCard(
          child: Column(
            children: [
              const CalcCardHeader(
                icon: Icons.swap_horiz_rounded,
                title: 'Unit Converter',
                description: 'Convert length units easily',
                iconColor: CalcColors.converter,
                iconBg: CalcColors.converterBg,
              ),
              Padding(
                padding: const EdgeInsets.all(CalcDimens.cardPadding),
                child: Column(
                  children: [
                    CalcInputField(
                      label: 'Value',
                      controller: _valCtrl,
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
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CalcColors.converterBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CalcColors.converter.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text('Result', style: TextStyle(color: CalcColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${result.toStringAsFixed(4)} $_toUnit',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: CalcColors.converter,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
