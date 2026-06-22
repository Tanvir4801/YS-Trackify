import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

class LabourMyAttendanceScreen extends StatefulWidget {
  const LabourMyAttendanceScreen({
    super.key,
    required this.labourId,
    required this.contractorId,
  });

  final String labourId;
  final String contractorId;

  @override
  State<LabourMyAttendanceScreen> createState() =>
      _LabourMyAttendanceScreenState();
}

class _LabourMyAttendanceScreenState extends State<LabourMyAttendanceScreen> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
  }

  String _monthPrefix(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

  void _shiftMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta);
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _viewMonth.year == now.year && _viewMonth.month == now.month;
  }

  Stream<List<_DayRecord>> _stream() {
    return FirebaseFirestore.instance
        .collection('attendance')
        .where('labourId', isEqualTo: widget.labourId)
        .snapshots()
        .map((snap) {
      final prefix = _monthPrefix(_viewMonth);
      final records = <String, _DayRecord>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = (data['date'] as String?) ?? '';
        if (date.isEmpty || !date.startsWith(prefix)) continue;
        final cid = (data['contractorId'] as String?) ?? '';
        if (cid.isNotEmpty && cid != widget.contractorId) continue;
        final rawStatus = (data['status'] as String?) ?? 'absent';
        final normStatus = (rawStatus == 'half_day' || rawStatus == 'half-day')
            ? 'half'
            : rawStatus;
        records[date] = _DayRecord(
          date: date,
          status: normStatus,
          overtime: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
          markedVia: (data['markedVia'] as String?) ?? 'manual',
          markedAt: _toDate(data['syncedAt']) ?? _toDate(data['markedAt']),
        );
      }
      final list = records.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_DayRecord>>(
      stream: _stream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navy));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load attendance:\n${snap.error}',
                  textAlign: TextAlign.center)));
        }

        final records = snap.data ?? const <_DayRecord>[];
        var present = 0, absent = 0, half = 0;
        var worked = 0.0;
        for (final r in records) {
          switch (r.status) {
            case 'present': present += 1; worked += 1; break;
            case 'half':    half    += 1; worked += 0.5; break;
            case 'absent':  absent  += 1; break;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _MonthSwitcher(
              viewMonth: _viewMonth,
              isCurrentMonth: _isCurrentMonth,
              onPrev: () => _shiftMonth(-1),
              onNext: _isCurrentMonth ? null : () => _shiftMonth(1),
            ),
            const SizedBox(height: 14),
            _SummaryHeroCard(
              present: present, absent: absent,
              half: half, worked: worked,
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Text('DAILY BREAKDOWN',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary, letterSpacing: 1.2)),
              const Spacer(),
              if (_isCurrentMonth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.presentBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.present.withValues(alpha: 0.3))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bolt, size: 11, color: AppColors.present),
                    SizedBox(width: 3),
                    Text('LIVE', style: TextStyle(
                      color: AppColors.present, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ])),
            ]),
            const SizedBox(height: 10),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.calendar_month_outlined,
                      size: 48, color: AppColors.textTertiary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      _isCurrentMonth
                          ? 'No attendance marked yet this month.'
                          : 'No attendance recorded for this month.',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                  ])))
            else
              ...records.map((r) => _DayTile(
                record: r, formatDate: _formatDate)),
          ],
        );
      },
    );
  }
}

// ── Month Switcher ───────────────────────────────────────────────────────────
class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.viewMonth, required this.isCurrentMonth,
    required this.onPrev, required this.onNext,
  });

  final DateTime viewMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        _NavBtn(icon: Icons.chevron_left_rounded, onPressed: onPrev),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(viewMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800,
              fontSize: 15, color: AppColors.textPrimary))),
        _NavBtn(icon: Icons.chevron_right_rounded, onPressed: onNext),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon,
          color: enabled ? AppColors.navy : AppColors.textTertiary, size: 22)),
    );
  }
}

// ── Summary Hero Card ────────────────────────────────────────────────────────
class _SummaryHeroCard extends StatelessWidget {
  const _SummaryHeroCard({
    required this.present, required this.absent,
    required this.half, required this.worked,
  });

  final int present;
  final int absent;
  final int half;
  final double worked;

  @override
  Widget build(BuildContext context) {
    final total = present + absent + half;
    final rate  = total > 0 ? ((present + half * 0.5) / total * 100).round() : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF1A2438)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.35),
          blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Monthly Summary',
              style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3))),
              child: Text('$rate% rate', style: const TextStyle(
                color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12))),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _StatChip(label: 'Worked', value: worked.toStringAsFixed(1),
              icon: Icons.work_outline_rounded, color: AppColors.gold)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Present', value: '$present',
              icon: Icons.check_circle_rounded, color: AppColors.present)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Half Day', value: '$half',
              icon: Icons.schedule_rounded, color: AppColors.halfDay)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Absent', value: '$absent',
              icon: Icons.cancel_rounded, color: AppColors.absent)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Attendance Rate',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            Text('$rate%',
              style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold))),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label, required this.value,
    required this.icon, required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color,
        fontWeight: FontWeight.w900, fontSize: 18)),
      Text(label, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Day Tile ─────────────────────────────────────────────────────────────────
class _DayTile extends StatelessWidget {
  const _DayTile({required this.record, required this.formatDate});

  final _DayRecord record;
  final String Function(String) formatDate;

  Color get _color {
    switch (record.status) {
      case 'present': return AppColors.present;
      case 'half':    return AppColors.halfDay;
      default:        return AppColors.absent;
    }
  }

  Color get _bgColor {
    switch (record.status) {
      case 'present': return AppColors.presentBg;
      case 'half':    return AppColors.halfDayBg;
      default:        return AppColors.absentBg;
    }
  }

  IconData get _icon {
    switch (record.status) {
      case 'present': return Icons.check_circle_rounded;
      case 'half':    return Icons.schedule_rounded;
      default:        return Icons.cancel_rounded;
    }
  }

  String get _label {
    switch (record.status) {
      case 'present': return 'Present';
      case 'half':    return 'Half Day';
      default:        return 'Absent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final markedAtLabel = record.markedAt != null
        ? '${DateFormat('HH:mm').format(record.markedAt!.toLocal())} · ${record.markedVia}'
        : record.markedVia;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: _color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: _bgColor,
                borderRadius: BorderRadius.circular(13)),
              child: Icon(_icon, color: _color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatDate(record.date),
                style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(
                record.overtime > 0
                    ? '$markedAtLabel · OT ${record.overtime.toStringAsFixed(1)}h'
                    : markedAtLabel,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _bgColor, borderRadius: BorderRadius.circular(10)),
              child: Text(_label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _color))),
          ]),
        ),
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────
class _DayRecord {
  const _DayRecord({
    required this.date, required this.status, required this.overtime,
    required this.markedVia, this.markedAt,
  });

  final String   date;
  final String   status;
  final double   overtime;
  final String   markedVia;
  final DateTime? markedAt;
}
