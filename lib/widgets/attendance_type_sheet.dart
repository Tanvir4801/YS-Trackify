import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AttendanceTypeSheet extends StatefulWidget {
  const AttendanceTypeSheet({
    super.key,
    required this.labourName,
    required this.onSelected,
    this.autoConfirmSeconds = 3,
  });

  final String labourName;
  final ValueChanged<String> onSelected;
  final int autoConfirmSeconds;

  static Future<String?> show(
    BuildContext context, {
    required String labourName,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceTypeSheet(
        labourName: labourName,
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

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
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
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => _select('present'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.wb_sunny_rounded,
                                color: Colors.white, size: 24),
                            const SizedBox(height: 6),
                            const Text(
                              'Full Day',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedBuilder(
                              animation: _progressController,
                              builder: (_, __) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value:
                                            1 - _progressController.value,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.3),
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                Colors.white),
                                        minHeight: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Auto in ${_secondsLeft}s',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.9),
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
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _select('half'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.orange.shade300, width: 1.5),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.timelapse_rounded,
                                color: Colors.orange, size: 24),
                            SizedBox(height: 6),
                            Text(
                              'Half\nDay',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _select('cancel'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.close_rounded,
                                color: Colors.grey, size: 24),
                            SizedBox(height: 6),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
}
