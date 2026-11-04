import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/calc_constants.dart';

class CalcInputField extends StatefulWidget {
  final String label;
  final String? initialValue;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  
  const CalcInputField({
    super.key,
    required this.label,
    required this.controller,
    this.initialValue,
    this.hint,
    this.onChanged,
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
          style: CalcTextStyles.inputLabel(context),
        ),
        const SizedBox(height: 4),
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: TextFormField(
            controller: widget.controller,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
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
            style: CalcTextStyles.inputText(context),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 14, color: CalcColors.textMuted(context)),
              filled: true,
              fillColor: _focused
                  ? CalcColors.surface(context)
                  : CalcColors.inputBg(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  CalcDimens.radiusMd),
                borderSide: BorderSide(
                  color: CalcColors.border(context), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  CalcDimens.radiusMd),
                borderSide: BorderSide(
                  color: CalcColors.border(context), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  CalcDimens.radiusMd),
                borderSide: BorderSide(
                  color: CalcColors.amber(context), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
