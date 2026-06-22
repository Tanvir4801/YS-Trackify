import 'package:flutter/material.dart';
import '../utils/calc_constants.dart';

class CalcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;

  const CalcCard({
    super.key,
    required this.child,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CalcColors.surface,
        borderRadius: BorderRadius.circular(
          CalcDimens.radiusLg),
        border: Border.all(
          color: CalcColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class CalcCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color iconBg;

  const CalcCardHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF3F2EF), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: CalcDimens.cardIconSize,
            height: CalcDimens.cardIconSize,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(
                CalcDimens.radiusIcon),
            ),
            child: Icon(icon,
              size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: CalcTextStyles.cardTitle),
                Text(description,
                  style: CalcTextStyles.cardDesc),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
