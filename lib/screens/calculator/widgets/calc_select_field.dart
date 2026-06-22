import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';

class CalcSelectField extends StatelessWidget {
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const CalcSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: CalcTextStyles.inputLabel,
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: CalcColors.surface,
          items: items,
          onChanged: onChanged,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: CalcColors.textMuted,
          ),
          style: CalcTextStyles.inputText,
          decoration: InputDecoration(
            filled: true,
            fillColor: CalcColors.inputBg,
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
      ],
    );
  }
}
