import 'package:flutter/material.dart';

class LabourStatCard extends StatefulWidget {
  const LabourStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
    required this.icon,
    this.subtitle,
    this.isHighlighted = false,
    this.gradient,
  });

  final String title;
  final String value;
  final Color backgroundColor;
  final Color valueColor;
  final IconData icon;
  final String? subtitle;
  final bool isHighlighted;
  final Gradient? gradient;

  @override
  State<LabourStatCard> createState() => _LabourStatCardState();
}

class _LabourStatCardState extends State<LabourStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeScale,
      builder: (context, child) {
        return Transform.scale(
          scale: _fadeScale.value,
          child: Opacity(
            opacity: _fadeScale.value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: widget.gradient,
          color: widget.gradient == null ? widget.backgroundColor : null,
          borderRadius: BorderRadius.circular(widget.isHighlighted ? 22 : 18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: widget.isHighlighted ? 18 : 14,
              offset: const Offset(0, 6),
            ),
            if (widget.isHighlighted)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: widget.valueColor, size: widget.isHighlighted ? 26 : 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: widget.valueColor,
                      fontWeight: FontWeight.w900,
                      fontSize: widget.isHighlighted ? 32 : 24,
                    ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
