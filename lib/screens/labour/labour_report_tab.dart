import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LabourReportTab extends StatefulWidget {
  const LabourReportTab({
    super.key,
    required this.labourId,
    required this.contractorId,
  });

  final String labourId;
  final String contractorId;

  @override
  State<LabourReportTab> createState() => _LabourReportTabState();
}

class _LabourReportTabState extends State<LabourReportTab> {
  final _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _flatSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nestedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paymentSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _labourDocSub;

  // All attendance docs (unfiltered — we filter by month in rebuild)
  final Map<String, Map<String, dynamic>> _flatDocs = {};
  final Map<String, Map<String, dynamic>> _nestedDocs = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _paymentDocs = [];

  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  int _daysPresent = 0;
  int _daysHalf = 0;
  int _daysAbsent = 0;
  double _totalOTHours = 0;
  double _dailyWage = 0;
  double _otRate = 0;
  double _grossSalary = 0;
  double _totalAdvances = 0;
  double _netPayable = 0;
  List<Map<String, dynamic>> _paymentHistory = [];

  bool _loading = true;

  static const _monthNames = [
    '',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _startStreams();
  }

  @override
  void dispose() {
    _flatSub?.cancel();
    _nestedSub?.cancel();
    _paymentSub?.cancel();
    _labourDocSub?.cancel();
    super.dispose();
  }

  void _startStreams() {
    // Cancel any existing subscriptions first
    _flatSub?.cancel();
    _nestedSub?.cancel();
    _paymentSub?.cancel();
    _labourDocSub?.cancel();

    // ── 1. Labour profile (wages) ──────────────────────────────────────
    _labourDocSub = _db
        .collection('labours')
        .doc(widget.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data() ?? {};
      _dailyWage =
          (data['dailyWage'] as num?)?.toDouble() ??
          (data['dailyRate'] as num?)?.toDouble() ?? 0;
      _otRate =
          (data['overtimeWagePerHour'] as num?)?.toDouble() ?? 0;
      _rebuild();
    }, onError: (e) {
      debugPrint('[LabourReportTab] labourDoc stream error: $e');
    });

    // ── 2. Flat attendance collection (primary, most reliable) ─────────
    _flatSub = _db
        .collection('attendance')
        .where('labourId', isEqualTo: widget.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      _flatDocs.clear();
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = (data['date'] as String?) ?? '';
        if (date.isNotEmpty) {
          _flatDocs['flat_${doc.id}'] = data;
        }
      }
      _rebuild();
    }, onError: (e) {
      debugPrint('[LabourReportTab] flat attendance stream error: $e');
      if (mounted) _rebuild();
    });

    // ── 3. Nested attendance path (supplementary) ──────────────────────
    // Uses collectionGroup — may fail without index. Error is swallowed
    // gracefully; flat collection data always covers this.
    _nestedSub = _db
        .collectionGroup('records')
        .where('labourId', isEqualTo: widget.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      _nestedDocs.clear();
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = (data['date'] as String?) ?? '';
        final labourId = (data['labourId'] as String?) ?? '';
        if (date.isNotEmpty && labourId.isNotEmpty) {
          _nestedDocs['nested_${labourId}_$date'] = data;
        }
      }
      _rebuild();
    }, onError: (e) {
      // collectionGroup may fail without a Firestore index — this is OK
      // since flat collection covers all attendance data
      debugPrint('[LabourReportTab] nested stream error (non-critical): $e');
    });

    // ── 4. Payments ────────────────────────────────────────────────────
    _paymentSub = _db
        .collection('payments')
        .where('labourId', isEqualTo: widget.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      _paymentDocs = snap.docs;
      _rebuild();
    }, onError: (e) {
      debugPrint('[LabourReportTab] payments stream error: $e');
      if (mounted) _rebuild();
    });
  }

  void _rebuild() {
    final monthStr = '$_year-${_month.toString().padLeft(2, '0')}';

    // Merge flat + nested, deduplicated by date key
    final attendance = <String, Map<String, dynamic>>{};

    for (final entry in _flatDocs.entries) {
      final data = entry.value;
      final date = (data['date'] as String?) ?? '';
      if (_matchesMonth(date, monthStr)) {
        // Use labourId+date as key to deduplicate
        final labourId = (data['labourId'] as String?) ?? '';
        attendance['${labourId}_$date'] = data;
      }
    }

    for (final entry in _nestedDocs.entries) {
      final data = entry.value;
      final date = (data['date'] as String?) ?? '';
      if (_matchesMonth(date, monthStr)) {
        final labourId = (data['labourId'] as String?) ?? '';
        final key = '${labourId}_$date';
        // Nested path takes precedence if both exist for same date
        attendance[key] = data;
      }
    }

    int daysPresent = 0;
    int daysHalf = 0;
    int daysAbsent = 0;
    double totalOTHours = 0;

    for (final data in attendance.values) {
      final status = _normalizeStatus(data['status']);
      final ot = (data['overtimeHours'] as num?)?.toDouble() ?? 0;
      if (status == 'present') {
        daysPresent++;
      } else if (status == 'half') {
        daysHalf++;
      } else if (status == 'absent') {
        daysAbsent++;
      }
      totalOTHours += ot;
    }

    final paymentHistory = <Map<String, dynamic>>[];
    double totalAdvances = 0;

    for (final doc in _paymentDocs) {
      final data = doc.data();
      final dateValue = data['date'];
      if (!_matchesMonthValue(dateValue, monthStr)) continue;
      final type = (data['type'] as String?) ?? '';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      if (type == 'advance') totalAdvances += amount;
      paymentHistory.add({...data, 'id': doc.id});
    }

    final workedDays = daysPresent + (daysHalf * 0.5);
    final grossSalary = (workedDays * _dailyWage) + (totalOTHours * _otRate);
    final netPayable = grossSalary - totalAdvances;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _daysPresent = daysPresent;
      _daysHalf = daysHalf;
      _daysAbsent = daysAbsent;
      _totalOTHours = totalOTHours;
      _grossSalary = grossSalary;
      _totalAdvances = totalAdvances;
      _netPayable = netPayable;
      _paymentHistory = paymentHistory;
    });
  }

  String _normalizeStatus(dynamic rawStatus) {
    final status = (rawStatus?.toString() ?? '').trim().toLowerCase();
    if (status == 'half_day' || status == 'half-day') return 'half';
    if (status == 'present' || status == 'absent' || status == 'half') {
      return status;
    }
    return '';
  }

  bool _matchesMonth(String date, String monthStr) =>
      date.startsWith(monthStr);

  bool _matchesMonthValue(dynamic value, String monthStr) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${ d.year}-${d.month.toString().padLeft(2, '0')}' == monthStr;
    }
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}' ==
          monthStr;
    }
    if (value is String) return value.startsWith(monthStr);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async => _startStreams(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMonthSelector(),
          const SizedBox(height: 16),
          _sectionCard('Attendance Summary', [
            _reportRow('Days Present', '$_daysPresent days',
                Icons.check_circle_outline, Colors.green),
            _reportRow('Half Days', '$_daysHalf days',
                Icons.timelapse_outlined, Colors.orange),
            _reportRow('Days Absent', '$_daysAbsent days',
                Icons.cancel_outlined, Colors.red),
            if (_totalOTHours > 0)
              _reportRow(
                  'Overtime Hours',
                  '${_totalOTHours.toStringAsFixed(1)} hrs',
                  Icons.bolt_outlined,
                  Colors.amber),
          ]),
          const SizedBox(height: 12),
          _sectionCard('Salary Summary', [
            _reportRow('Daily Wage', '₹${_dailyWage.toStringAsFixed(0)}',
                Icons.currency_rupee, Colors.blue),
            _reportRow('Gross Salary',
                '₹${_grossSalary.toStringAsFixed(0)}',
                Icons.account_balance_wallet_outlined, Colors.teal),
            _reportRow('Advances Taken',
                '₹${_totalAdvances.toStringAsFixed(0)}',
                Icons.arrow_upward_outlined, Colors.orange),
            _netRow(),
          ]),
          if (_paymentHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Payment History',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._paymentHistory.map((p) => _paymentItem(p)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              if (_month == 1) {
                _month = 12;
                _year--;
              } else {
                _month--;
              }
            });
            _rebuild();
          },
        ),
        Text(
          '${_monthNames[_month]} $_year',
          style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: (_year < now.year ||
                  (_year == now.year && _month < now.month))
              ? () {
                  setState(() {
                    if (_month == 12) {
                      _month = 1;
                      _year++;
                    } else {
                      _month++;
                    }
                  });
                  _rebuild();
                }
              : null,
        ),
      ],
    );
  }

  Widget _sectionCard(String title, List<Widget> rows) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey),
              ),
            ),
            ...rows,
          ],
        ),
      );

  Widget _reportRow(
          String label, String value, IconData icon, Color color) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _netRow() => Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _netPayable >= 0
              ? Colors.green.shade50
              : Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_outlined,
              color: _netPayable >= 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 10),
            const Text('Net Payable',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              '₹${_netPayable.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _netPayable >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      );

  Widget _paymentItem(Map<String, dynamic> p) {
    final type = p['type'] as String? ?? '';
    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
    final dateRaw = p['date'];
    DateTime? date;
    if (dateRaw is Timestamp) date = dateRaw.toDate();
    if (dateRaw is DateTime) date = dateRaw;
    if (dateRaw is String) date = DateTime.tryParse(dateRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.currency_rupee,
                size: 16, color: Colors.orange),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey),
              ),
              if (date != null)
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          const Spacer(),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
