import 'package:flutter/material.dart';

class StaggeredFadeIn extends StatelessWidget {
  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.delayMs = 60,
  });

  final int index;
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * delayMs).clamp(0, 600)),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) => Opacity(
        opacity: val,
        child: Transform.translate(
          offset: Offset(0, (1 - val) * 16),
          child: child,
        ),
      ),
    );
  }
}
