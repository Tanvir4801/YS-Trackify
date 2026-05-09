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
  bool _loading = true;

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

  static const _monthNames = [
    '',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final monthStr =
          '$_year-${_month.toString().padLeft(2, '0')}';

      final labourDoc =
          await _db.collection('labours').doc(widget.labourId).get();

      if (labourDoc.exists) {
        _dailyWage =
            (labourDoc.data()?['dailyWage'] as num?)?.toDouble() ?? 0;
        _otRate =
            (labourDoc.data()?['overtimeWagePerHour'] as num?)
                    ?.toDouble() ??
                0;
      }

      final attSnap = await _db
          .collection('attendance')
          .where('labourId', isEqualTo: widget.labourId)
          .where('date', isGreaterThanOrEqualTo: '$monthStr-01')
          .where('date', isLessThanOrEqualTo: '$monthStr-31')
          .get();

      _daysPresent = 0;
      _daysHalf = 0;
      _daysAbsent = 0;
      _totalOTHours = 0;

      for (var doc in attSnap.docs) {
        final status = doc.data()['status'] as String? ?? '';
        final ot =
            (doc.data()['overtimeHours'] as num?)?.toDouble() ?? 0;
        if (status == 'present') {
          _daysPresent++;
        } else if (status == 'half') {
          _daysHalf++;
        } else if (status == 'absent') {
          _daysAbsent++;
        }
        _totalOTHours += ot;
      }

      final workedDays = _daysPresent + (_daysHalf * 0.5);
      _grossSalary =
          (workedDays * _dailyWage) + (_totalOTHours * _otRate);

      final startDate = DateTime(_year, _month, 1);
      final endDate = DateTime(_year, _month + 1, 0, 23, 59, 59);

      final paySnap = await _db
          .collection('payments')
          .where('labourId', isEqualTo: widget.labourId)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      _totalAdvances = 0;
      _paymentHistory = [];

      for (var doc in paySnap.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        if (type == 'advance') _totalAdvances += amount;
        _paymentHistory.add({...data, 'id': doc.id});
      }

      _netPayable = _grossSalary - _totalAdvances;
    } catch (e) {
      debugPrint('LabourReportTab error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
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
            _reportRow('Daily Wage',
                '₹${_dailyWage.toStringAsFixed(0)}',
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
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
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
            _loadReport();
          },
        ),
        Text(
          '${_monthNames[_month]} $_year',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            if (_year < now.year ||
                (_year == now.year && _month < now.month)) {
              setState(() {
                if (_month == 12) {
                  _month = 1;
                  _year++;
                } else {
                  _month++;
                }
              });
              _loadReport();
            }
          },
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
            Text(label,
                style: const TextStyle(fontSize: 13)),
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
                color:
                    _netPayable >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      );

  Widget _paymentItem(Map<String, dynamic> p) {
    final type = p['type'] as String? ?? '';
    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
    final date = (p['date'] as Timestamp?)?.toDate();
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
