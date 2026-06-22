import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';

class UtilisationBar extends StatelessWidget {
  final double utilisation; // 0.0 to 1.0+
  final String label;

  const UtilisationBar({
    super.key,
    required this.utilisation,
    this.label = 'Utilisation',
  });

  @override
  Widget build(BuildContext context) {
    final pct = (utilisation * 100).toStringAsFixed(1);
    final isSafe = utilisation <= 1.0;
    final fillColor = isSafe ? CalcColors.green : CalcColors.red;
    final clampedWidth = utilisation.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                style: const TextStyle(
                  fontSize: 13, color: CalcColors.greenMid)),
              Text('$pct%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fillColor,
                )),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clampedWidth),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (ctx, val, _) => LinearProgressIndicator(
                value: val,
                minHeight: 6,
                backgroundColor: isSafe
                  ? CalcColors.greenDivider
                  : CalcColors.redBorder,
                valueColor: AlwaysStoppedAnimation(fillColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
