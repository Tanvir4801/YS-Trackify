import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/date_utils.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/labour_model.dart';
import '../providers/attendance_provider.dart';
import '../widgets/empty_state.dart';

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
            .where((s) => s == 'present')
            .length;
        final absentCount = attendanceByLabour.values
            .where((s) => s == 'absent')
            .length;
        final halfDayCount = attendanceByLabour.values
            .where((s) => s == 'half')
            .length;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _buildDateBar(context, data),
              _buildSummaryRow(presentCount, absentCount, halfDayCount),
              Expanded(
                child: Stack(
                  children: [
                    data.labours.isEmpty
                        ? const EmptyState(
                            icon: Icons.fact_check_outlined,
                            title: 'No Labour Added',
                            subtitle: 'Add labours first to mark attendance.',
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: data.initialize,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: data.labours.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final labour = data.labours[index];
                                final status = attendanceByLabour[labour.id];
                                return _AttendanceCard(
                                  labour: labour,
                                  status: status,
                                  data: data,
                                );
                              },
                            ),
                          ),
                    if (data.isLoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.1),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
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

  Widget _buildDateBar(BuildContext context, AttendanceProvider data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppDateUtils.toDisplay(data.selectedDate),
              style: AppTextStyles.headingMedium,
            ),
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: data.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) data.changeDate(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Change',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(int present, int absent, int half) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(child: _SummaryChip(label: 'Present', count: present, color: AppColors.present, bg: AppColors.presentSurface)),
          const SizedBox(width: 8),
          Expanded(child: _SummaryChip(label: 'Absent', count: absent, color: AppColors.absent, bg: AppColors.absentSurface)),
          const SizedBox(width: 8),
          Expanded(child: _SummaryChip(label: 'Half Day', count: half, color: AppColors.halfDay, bg: AppColors.halfSurface)),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });

  final String label;
  final int count;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.labour,
    required this.status,
    required this.data,
  });

  final Labour labour;
  final String? status;
  final AttendanceProvider data;

  @override
  Widget build(BuildContext context) {
    final initial = labour.name.isNotEmpty
        ? labour.name[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labour.name,
                        style: AppTextStyles.headingMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${labour.phone}  •  ₹${labour.dailyWage.toStringAsFixed(0)}/day',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (status != null) _statusIndicator(status!),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statusBtn('P', 'Present', status == 'present',
                    AppColors.present,
                    () => data.markAttendance(labour.id, 'present')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusBtn('A', 'Absent', status == 'absent',
                    AppColors.absent,
                    () => data.markAttendance(labour.id, 'absent')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusBtn('H', 'Half', status == 'half',
                    AppColors.halfDay,
                    () => data.markAttendance(labour.id, 'half')),
              ),
            ],
          ),
          if (status == 'present' || status == 'half') ...[
            const SizedBox(height: 10),
            _OvertimeField(
              key: ValueKey('ot_${labour.id}_${data.selectedDateStr}'),
              labourId: labour.id,
              initial: data.overtimeMap[labour.id] ?? 0,
              overtimeRate: labour.overtimeWagePerHour,
              onChanged: (h) => data.setOvertime(labour.id, h),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIndicator(String s) {
    final color = s == 'present'
        ? AppColors.present
        : s == 'absent'
            ? AppColors.absent
            : AppColors.halfDay;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _statusBtn(String short, String label, bool selected, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.2),
            width: selected ? 0 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            selected ? label : short,
            style: TextStyle(
              fontSize: selected ? 12 : 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.halfSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.halfDay.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_outlined, size: 15, color: AppColors.halfDay),
          const SizedBox(width: 6),
          const Text(
            'OT hrs',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.halfDay,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            height: 34,
            child: TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,2}(\.\d{0,1})?')),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.border),
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
                '+ ₹${pay.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.halfDay,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (widget.overtimeRate == 0)
            const Expanded(
              child: Text(
                'Set OT rate in labour profile',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
