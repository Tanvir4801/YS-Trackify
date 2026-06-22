import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AttendanceTypeSheet extends StatefulWidget {
  const AttendanceTypeSheet({
    super.key,
    required this.labourName,
    required this.onSelected,
    this.remainingFactor = 1.0,
    this.autoConfirmSeconds = 3,
  });

  final String labourName;
  final double remainingFactor;
  final ValueChanged<String> onSelected;
  final int autoConfirmSeconds;

  static Future<String?> show(
    BuildContext context, {
    required String labourName,
    double remainingFactor = 1.0,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceTypeSheet(
        labourName: labourName,
        remainingFactor: remainingFactor,
        onSelected: (type) => Navigator.of(context).pop(type),
      ),
    );
  }

  @override
  State<AttendanceTypeSheet> createState() => _AttendanceTypeSheetState();
}

class _AttendanceTypeSheetState extends State<AttendanceTypeSheet>
    with SingleTickerProviderStateMixin {
  late int _secondsLeft;
  Timer? _timer;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.autoConfirmSeconds;

    if (widget.remainingFactor >= 1.0) {
      _progressController = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.autoConfirmSeconds),
      )..forward();

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) {
          t.cancel();
          HapticFeedback.lightImpact();
          widget.onSelected('present');
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.remainingFactor >= 1.0) {
      _progressController.dispose();
    }
    super.dispose();
  }

  void _select(String type) {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    widget.onSelected(type);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              widget.labourName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'QR verified successfully',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select attendance type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (widget.remainingFactor >= 1.0)
                    Expanded(
                      flex: 2,
                      child: _buildOption(
                        type: 'present',
                        label: 'Full Day',
                        icon: Icons.wb_sunny_rounded,
                        color: Colors.green,
                        isPrimary: true,
                        autoConfirm: true,
                      ),
                    ),
                  if (widget.remainingFactor >= 0.75 && widget.remainingFactor < 1.0)
                    Expanded(
                      flex: 2,
                      child: _buildOption(
                        type: 'three_quarter',
                        label: '¾ Day',
                        icon: Icons.pie_chart_rounded,
                        color: Colors.teal,
                        isPrimary: true,
                        autoConfirm: false,
                      ),
                    ),
                  if (widget.remainingFactor >= 0.5) ...[
                    if (widget.remainingFactor >= 0.75) const SizedBox(width: 10),
                    Expanded(
                      flex: widget.remainingFactor < 0.75 ? 2 : 1,
                      child: _buildOption(
                        type: 'half',
                        label: 'Half\nDay',
                        icon: Icons.timelapse_rounded,
                        color: Colors.orange,
                        isPrimary: widget.remainingFactor < 0.75,
                        autoConfirm: false,
                      ),
                    ),
                  ],
                  if (widget.remainingFactor >= 0.25) ...[
                    if (widget.remainingFactor >= 0.5) const SizedBox(width: 10),
                    Expanded(
                      flex: widget.remainingFactor < 0.5 ? 2 : 1,
                      child: _buildOption(
                        type: 'quarter',
                        label: '1/4\nDay',
                        icon: Icons.pie_chart_outline_rounded,
                        color: Colors.blueGrey,
                        isPrimary: widget.remainingFactor < 0.5,
                        autoConfirm: false,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: _buildOption(
                      type: 'cancel',
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      color: Colors.grey,
                      isPrimary: false,
                      autoConfirm: false,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.remainingFactor < 1.0)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '${(1.0 - widget.remainingFactor).toStringAsFixed(2)} already used today',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (widget.remainingFactor >= 1.0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Full Day auto-selected in ${_secondsLeft}s. '
                  'You can change it later in Attendance.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required String type,
    required String label,
    required IconData icon,
    required MaterialColor color,
    required bool isPrimary,
    required bool autoConfirm,
  }) {
    final bgColor = isPrimary ? color : color.shade50;
    final contentColor = isPrimary ? Colors.white : color;
    final borderColor = isPrimary ? Colors.transparent : color.shade300;

    return GestureDetector(
      onTap: () => _select(type),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isPrimary ? 16 : 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isPrimary ? 0 : 1.5),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: contentColor, size: isPrimary ? 24 : 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: contentColor,
                fontWeight: FontWeight.w700,
                fontSize: isPrimary ? 14 : 12,
              ),
            ),
            if (autoConfirm) const SizedBox(height: 4),
            if (autoConfirm)
              AnimatedBuilder(
                animation: _progressController,
                builder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: 1 - _progressController.value,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Auto in ${_secondsLeft}s',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
