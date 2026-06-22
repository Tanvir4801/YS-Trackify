import 'package:flutter/material.dart';

class CountUpNumber extends StatelessWidget {
  const CountUpNumber({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 700),
  });

  final num value;
  final TextStyle style;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, _) => Text(
        '$prefix${val.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}$suffix',
        style: style,
      ),
    );
  }
}
