import 'package:flutter/material.dart';
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
