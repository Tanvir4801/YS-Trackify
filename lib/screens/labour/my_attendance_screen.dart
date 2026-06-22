import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String _monthPrefix(DateTime month) {
    return '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
  }

  void _shiftMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta);
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _viewMonth.year == now.year && _viewMonth.month == now.month;
  }

  /// Streams the labour's attendance for [_viewMonth] from the legacy flat
  /// `attendance` collection (which is dual-written from the new nested path
  /// `attendance/{contractorId}/dates/{dateKey}/records/{labourId}` so it is
  /// the equivalent live source). Filtered client-side by month + contractorId.
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
        // Allow legacy docs missing contractorId to still appear.
        if (cid.isNotEmpty && cid != widget.contractorId) continue;

        records[date] = _DayRecord(
          date: date,
          status: (data['status'] as String?) ?? 'absent',
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_DayRecord>>(
      stream: _stream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load attendance:\n${snap.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }

        final records = snap.data ?? const <_DayRecord>[];
        var present = 0, absent = 0, half = 0;
        var worked = 0.0;
        for (final r in records) {
          switch (r.status) {
            case 'present':
              present += 1;
              worked += 1;
              break;
            case 'half':
              half += 1;
              worked += 0.5;
              break;
            case 'absent':
              absent += 1;
              break;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMonthSwitcher(),
            const SizedBox(height: 14),
            _buildSummaryCards(
              present: present,
              absent: absent,
              half: half,
              worked: worked,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Daily breakdown',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                if (_isCurrentMonth)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.bolt, size: 11, color: Colors.green),
                        SizedBox(width: 2),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    _isCurrentMonth
                        ? 'No attendance marked yet this month.'
                        : 'No attendance recorded for this month.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...records.map(_buildDayTile),
          ],
        );
      },
    );
  }

  Widget _buildMonthSwitcher() {
    final label = DateFormat('MMMM yyyy').format(_viewMonth);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shiftMonth(-1),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards({
    required int present,
    required int absent,
    required int half,
    required double worked,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Worked Days',
                value: worked.toStringAsFixed(1),
                color: Colors.indigo,
                icon: Icons.work_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                label: 'Present',
                value: '$present',
                color: Colors.green,
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Half Day',
                value: '$half',
                color: Colors.orange,
                icon: Icons.timelapse,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                label: 'Absent',
                value: '$absent',
                color: Colors.red,
                icon: Icons.cancel_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayTile(_DayRecord r) {
    final color = r.status == 'present'
        ? Colors.green
        : r.status == 'half'
            ? Colors.orange
            : Colors.red;
    final dateLabel = _formatDate(r.date);
    final markedAtLabel = r.markedAt != null
        ? '${DateFormat('HH:mm').format(r.markedAt!.toLocal())} • ${r.markedVia}'
        : r.markedVia;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            r.status == 'present'
                ? Icons.check
                : r.status == 'half'
                    ? Icons.timelapse
                    : Icons.close,
            color: color,
            size: 18,
          ),
        ),
        title: Text(
          dateLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          r.overtime > 0
              ? '$markedAtLabel  •  OT ${r.overtime.toStringAsFixed(1)}h'
              : markedAtLabel,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            r.status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String yyyymmdd) {
    final parsed = DateTime.tryParse(yyyymmdd);
    if (parsed == null) return yyyymmdd;
    return DateFormat('EEE, dd MMM').format(parsed);
  }
}

class _DayRecord {
  _DayRecord({
    required this.date,
    required this.status,
    required this.overtime,
    required this.markedVia,
    this.markedAt,
  });

  final String date;
  final String status;
  final double overtime;
  final String markedVia;
  final DateTime? markedAt;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
