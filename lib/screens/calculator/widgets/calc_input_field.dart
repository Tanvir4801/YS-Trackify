import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/calc_constants.dart';

class CalcInputField extends StatefulWidget {
  final String label;
  final String? initialValue;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  
  const CalcInputField({
    super.key,
    required this.label,
    required this.controller,
    this.initialValue,
    this.hint,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
  });

  @override
  State<CalcInputField> createState() => _CalcInputFieldState();
}

class _CalcInputFieldState extends State<CalcInputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: CalcTextStyles.inputLabel,
        ),
        const SizedBox(height: 4),
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: TextFormField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d*')),
            ],
            onTap: () {
              widget.controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: widget.controller.text.length,
              );
            },
            style: CalcTextStyles.inputText,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                fontSize: 14, color: CalcColors.textMuted),
              filled: true,
              fillColor: _focused
                  ? CalcColors.surface
                  : CalcColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  CalcDimens.radiusMd),
                borderSide: const BorderSide(
                  color: CalcColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  CalcDimens.radiusMd),
                borderSide: const BorderSide(
                  color: CalcColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  CalcDimens.radiusMd),
                borderSide: const BorderSide(
                  color: CalcColors.amber, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
