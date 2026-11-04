import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool useBlur;
  final EdgeInsetsGeometry padding;
  final Color? baseColorTint;
  final double tintOpacityLight;
  final double tintOpacityDark;
  final double borderRadius;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.useBlur = false,
    this.padding = const EdgeInsets.all(16),
    this.baseColorTint,
    this.tintOpacityLight = 0.82,
    this.tintOpacityDark = 0.08,
    this.borderRadius = 24.0,
    this.glowColor,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine the base surface color
    Color surfaceColor;
    Gradient? surfaceGradient;
    
    if (isDark) {
      if (widget.glowColor != null) {
        surfaceColor = Colors.black.withValues(alpha: 0.3);
        surfaceGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.2),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        );
      } else if (widget.baseColorTint != null) {
        surfaceColor = widget.baseColorTint!.withValues(alpha: widget.tintOpacityDark);
      } else {
        surfaceColor = Colors.transparent;
        surfaceGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F1A2A), Color(0xFF0A1322)],
        );
      }
    } else {
      if (widget.baseColorTint != null) {
        surfaceColor = widget.baseColorTint!.withValues(alpha: widget.tintOpacityLight);
      } else {
        surfaceColor = _isPressed ? const Color(0xFFFFFFFF).withValues(alpha: 0.88) : const Color(0xFFFFFFFF).withValues(alpha: 0.82);
      }
    }

    // Determine border color
    Color borderColor;
    if (isDark) {
      if (widget.glowColor != null) {
        borderColor = widget.glowColor!.withValues(alpha: 0.4);
        if (_isPressed) {
          borderColor = widget.glowColor!.withValues(alpha: 0.7);
        }
      } else {
        borderColor = const Color(0xFF91AAC8).withValues(alpha: 0.12);
        if (_isPressed) {
          borderColor = borderColor.withValues(alpha: 0.3);
        }
      }
    } else {
      borderColor = widget.baseColorTint != null
          ? widget.baseColorTint!.withValues(alpha: 0.4)
          : const Color(0xFFFFFFFF).withValues(alpha: 0.75);
          
      if (_isPressed) {
        borderColor = const Color(0xFFFFFFFF).withValues(alpha: 0.9);
      }
    }

    // Outer glow for dark mode
    final boxShadow = [
      if (isDark && widget.glowColor != null)
        BoxShadow(
          color: widget.glowColor!.withValues(alpha: 0.15),
          blurRadius: 32,
          spreadRadius: 2,
          offset: Offset.zero,
        )
      else if (isDark)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 24,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        )
      else
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 30,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
    ];

    Widget innerContent = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        gradient: surfaceGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: widget.child,
    );

    if (widget.useBlur && (!isDark || widget.glowColor != null)) {
      innerContent = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: innerContent,
        ),
      );
    }

    Widget content = AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: boxShadow,
        ),
        child: innerContent,
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap!();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}
