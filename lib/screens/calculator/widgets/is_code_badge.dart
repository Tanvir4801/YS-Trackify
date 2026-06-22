import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';

class ISCodeBadge extends StatelessWidget {
  final String code;
  const ISCodeBadge({
    super.key,
    this.code = 'IS 456:2000 guideline',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CalcColors.isBadgeBg,
        border: Border.all(
          color: CalcColors.isBadgeBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline_rounded,
            size: 12,
            color: CalcColors.isBadgeIcon),
          const SizedBox(width: 4),
          Text(code,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: CalcColors.isBadgeText,
            )),
        ],
      ),
    );
  }
}
