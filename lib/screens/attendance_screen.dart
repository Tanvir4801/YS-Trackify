import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/date_utils.dart';
import '../core/theme/app_colors.dart';
import '../providers/attendance_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, data, _) {
        final attendanceByLabour = data.attendanceMap;
        final presentCount = attendanceByLabour.values
            .where((status) => status == 'present')
            .length;
        final absentCount = attendanceByLabour.values
            .where((status) => status == 'absent')
            .length;
        final halfDayCount = attendanceByLabour.values
            .where((status) => status == 'half')
            .length;

        return Scaffold(
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.blueCard,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppDateUtils.toDisplay(data.selectedDate),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: data.selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          data.changeDate(picked);
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryChip(
                        label: 'Present',
                        count: presentCount,
                        color: AppColors.present,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryChip(
                        label: 'Absent',
                        count: absentCount,
                        color: AppColors.absent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryChip(
                        label: 'Half-day',
                        count: halfDayCount,
                        color: AppColors.halfDay,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    data.labours.isEmpty
                        ? const Center(child: Text('Add labour first to mark attendance'))
                        : RefreshIndicator(
                            onRefresh: data.initialize,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: data.labours.length,
                              itemBuilder: (context, index) {
                                final labour = data.labours[index];
                                final status = attendanceByLabour[labour.id];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          labour.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${labour.phone} • Rs ${labour.dailyWage.toStringAsFixed(0)}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).textTheme.bodySmall?.color,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          spacing: 8,
                                          children: [
                                            Expanded(
                                              child: _statusButton(
                                                context: context,
                                                label: 'P',
                                                selected: status == 'present',
                                                color: AppColors.present,
                                                onTap: () => data.markAttendance(labour.id, 'present'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _statusButton(
                                                context: context,
                                                label: 'A',
                                                selected: status == 'absent',
                                                color: AppColors.absent,
                                                onTap: () => data.markAttendance(labour.id, 'absent'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _statusButton(
                                                context: context,
                                                label: 'H',
                                                selected: status == 'half',
                                                color: AppColors.halfDay,
                                                onTap: () => data.markAttendance(labour.id, 'half'),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Per-day OT input. Only meaningful when
                                        // labour is marked Present or Half-day.
                                        if (status == 'present' || status == 'half') ...[
                                          const SizedBox(height: 8),
                                          _OvertimeField(
                                            key: ValueKey(
                                                'ot_${labour.id}_${data.selectedDateStr}'),
                                            labourId: labour.id,
                                            initial: data.overtimeMap[labour.id] ?? 0,
                                            overtimeRate:
                                                labour.overtimeWagePerHour,
                                            onChanged: (h) =>
                                                data.setOvertime(labour.id, h),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    if (data.isLoading)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black12,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusButton({
    required BuildContext context,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40,
      child: AnimatedScale(
        scale: selected ? 1.02 : 1,
        duration: const Duration(milliseconds: 140),
        child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? color : color.withValues(alpha: 0.2),
          foregroundColor: selected ? Colors.white : color,
          elevation: selected ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact OT-hours input shown beneath the status pills.
/// Debounces user input so we don't spam Firestore on every keystroke.
class _OvertimeField extends StatefulWidget {
  const _OvertimeField({
    super.key,
    required this.labourId,
    required this.initial,
    required this.overtimeRate,
    required this.onChanged,
  });

  final String labourId;
  final double initial;
  final double overtimeRate;
  final ValueChanged<double> onChanged;

  @override
  State<_OvertimeField> createState() => _OvertimeFieldState();
}

class _OvertimeFieldState extends State<_OvertimeField> {
  late final TextEditingController _controller;
  Timer? _debounce;
  double _lastSent = 0;

  @override
  void initState() {
    super.initState();
    _lastSent = widget.initial;
    _controller = TextEditingController(
      text: widget.initial > 0 ? _format(widget.initial) : '',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  void _scheduleSend(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final parsed = double.tryParse(raw.trim()) ?? 0;
      final clamped = parsed.isFinite && parsed >= 0 ? parsed : 0.0;
      if ((clamped - _lastSent).abs() < 0.0001) return;
      _lastSent = clamped;
      widget.onChanged(clamped);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = double.tryParse(_controller.text.trim()) ?? 0;
    final pay = hours * widget.overtimeRate;

    return Row(
      children: [
        const Icon(Icons.bolt_outlined, size: 16, color: Colors.orange),
        const SizedBox(width: 6),
        const Text(
          'OT hrs',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          height: 36,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,1})?')),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: _scheduleSend,
            onSubmitted: (v) {
              _debounce?.cancel();
              final parsed = double.tryParse(v.trim()) ?? 0;
              _lastSent = parsed;
              widget.onChanged(parsed);
            },
          ),
        ),
        const SizedBox(width: 10),
        if (widget.overtimeRate > 0 && hours > 0)
          Expanded(
            child: Text(
              '+ Rs ${pay.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else if (widget.overtimeRate == 0)
          const Expanded(
            child: Text(
              'Set OT rate in labour',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
