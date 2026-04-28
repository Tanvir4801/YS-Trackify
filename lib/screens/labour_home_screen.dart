import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import 'qr/qr_screen.dart';

class LabourHomeScreen extends StatefulWidget {
  const LabourHomeScreen({super.key});

  @override
  State<LabourHomeScreen> createState() => _LabourHomeScreenState();
}

class _LabourHomeScreenState extends State<LabourHomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  _LabourSession? _session;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Not logged in');
      }

      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('Not registered');
      }

      final data = userDoc.data() ?? <String, dynamic>{};
      final role = (data['role'] as String? ?? '').trim();
      final isActive = data['isActive'] as bool? ?? true;
      if (!isActive) {
        throw Exception('Account disabled');
      }
      if (role != 'labour') {
        throw Exception('This account is not a labour account');
      }

      final phone = _digitsOnly((data['phone'] as String?) ?? user.phoneNumber ?? '');
      final userName = (data['name'] as String? ?? 'Labour').trim();
      var labourId = (data['labourId'] as String? ?? '').trim();
      var supervisorId = (data['supervisorId'] as String? ?? '').trim();

      if (labourId.isEmpty && phone.length == 10) {
        final labourSnap = await _db
            .collection('labours')
            .where('phone', isEqualTo: phone)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (labourSnap.docs.isNotEmpty) {
          labourId = labourSnap.docs.first.id;
          supervisorId =
              (labourSnap.docs.first.data()['supervisorId'] as String? ?? '').trim();
          await _db.collection('users').doc(user.uid).set({
            'labourId': labourId,
            'supervisorId': supervisorId,
            'phone': phone,
          }, SetOptions(merge: true));
        }
      }

      if (labourId.isEmpty) {
        throw Exception('Labour profile not found. Contact supervisor.');
      }

      _session = _LabourSession(
        uid: user.uid,
        phone: phone,
        role: role,
        userName: userName,
        labourId: labourId,
        supervisorId: supervisorId,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _digitsOnly(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().logout();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Labour Home'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 10),
                Text(_error ?? 'Unable to load labour profile'),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _loadSession,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabs = <Widget>[
      _LabourDashboardTab(session: session),
      _LabourAttendanceTab(session: session),
      _LabourPaymentsTab(session: session),
      const QRScreen(showAppBar: false),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Labour Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _tabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            label: 'QR',
          ),
        ],
      ),
    );
  }
}

class _LabourSession {
  const _LabourSession({
    required this.uid,
    required this.phone,
    required this.role,
    required this.userName,
    required this.labourId,
    required this.supervisorId,
  });

  final String uid;
  final String phone;
  final String role;
  final String userName;
  final String labourId;
  final String supervisorId;
}

class _LabourDashboardTab extends StatelessWidget {
  const _LabourDashboardTab({required this.session});

  final _LabourSession session;

  @override
  Widget build(BuildContext context) {
    final labourStream = FirebaseFirestore.instance
        .collection('labours')
        .doc(session.labourId)
        .snapshots();

    final attendanceStream = FirebaseFirestore.instance
        .collection('attendance')
        .where('labourId', isEqualTo: session.labourId)
        .snapshots();

    final paymentsStream = FirebaseFirestore.instance
        .collection('payments')
        .where('labourId', isEqualTo: session.labourId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: labourStream,
      builder: (context, labourSnap) {
        final labourData = labourSnap.data?.data() ?? <String, dynamic>{};
        final labourName = (labourData['name'] as String?)?.trim().isNotEmpty == true
            ? labourData['name'] as String
            : session.userName;
        final dailyWage = (labourData['dailyWage'] as num?)?.toDouble() ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: attendanceStream,
          builder: (context, attendanceSnap) {
            final attendanceDocs = attendanceSnap.data?.docs ?? const [];
            final now = DateTime.now();
            final monthPrefix = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

            var present = 0;
            var absent = 0;
            var half = 0;
            var workedDays = 0.0;

            for (final doc in attendanceDocs) {
              final data = doc.data();
              final date = (data['date'] as String?) ?? '';
              if (!date.startsWith(monthPrefix)) {
                continue;
              }
              final status = (data['status'] as String?) ?? '';
              if (status == 'present') {
                present += 1;
                workedDays += 1;
              } else if (status == 'half') {
                half += 1;
                workedDays += 0.5;
              } else if (status == 'absent') {
                absent += 1;
              }
            }

            final gross = workedDays * dailyWage;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: paymentsStream,
              builder: (context, paymentSnap) {
                final paymentDocs = paymentSnap.data?.docs ?? const [];
                var advances = 0.0;

                for (final doc in paymentDocs) {
                  final data = doc.data();
                  final type = (data['type'] as String?) ?? '';
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                  if (type == 'advance') {
                    advances += amount;
                  }
                }

                final net = gross - advances;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      labourName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text('Phone: ${session.phone}'),
                    const SizedBox(height: 18),
                    _MetricCard(title: 'Daily Wage', value: 'Rs ${dailyWage.toStringAsFixed(0)}'),
                    const SizedBox(height: 10),
                    _MetricCard(title: 'Worked Days (This Month)', value: workedDays.toStringAsFixed(1)),
                    const SizedBox(height: 10),
                    _MetricCard(title: 'Gross (This Month)', value: 'Rs ${gross.toStringAsFixed(0)}'),
                    const SizedBox(height: 10),
                    _MetricCard(title: 'Advance Paid', value: 'Rs ${advances.toStringAsFixed(0)}'),
                    const SizedBox(height: 10),
                    _MetricCard(title: 'Net Payable', value: 'Rs ${net.toStringAsFixed(0)}'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _StatusChip(label: 'Present', count: present, color: Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatusChip(label: 'Absent', count: absent, color: Colors.red)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatusChip(label: 'Half', count: half, color: Colors.orange)),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LabourAttendanceTab extends StatelessWidget {
  const _LabourAttendanceTab({required this.session});

  final _LabourSession session;

  DateTime? _toDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  String _formatDate(dynamic raw) {
    final date = _toDate(raw);
    if (date != null) {
      return DateFormat('dd MMM yyyy').format(date);
    }
    if (raw is String && raw.isNotEmpty) {
      return raw;
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('attendance')
        .where('labourId', isEqualTo: session.labourId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) {
            final aDate = _toDate(a.data()['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = _toDate(b.data()['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

        if (docs.isEmpty) {
          return const Center(child: Text('No attendance data available'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final date = _formatDate(data['date']);
            final status = (data['status'] as String?) ?? '-';
            final overtime = (data['overtimeHours'] as num?)?.toDouble() ?? 0;
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(date),
              subtitle: Text('Overtime: ${overtime.toStringAsFixed(1)} h'),
              trailing: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: status == 'present'
                      ? Colors.green
                      : status == 'absent'
                          ? Colors.red
                          : Colors.orange,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LabourPaymentsTab extends StatelessWidget {
  const _LabourPaymentsTab({required this.session});

  final _LabourSession session;

  DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('payments')
        .where('labourId', isEqualTo: session.labourId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) => _toDate(b.data()['date']).compareTo(_toDate(a.data()['date'])));

        if (docs.isEmpty) {
          return const Center(child: Text('No payments found'));
        }

        final total = docs.fold<double>(
          0,
          (acc, doc) => acc + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
        );

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _MetricCard(title: 'Total Payments', value: 'Rs ${total.toStringAsFixed(0)}');
            }
            final data = docs[index - 1].data();
            final date = _toDate(data['date']);
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            final type = (data['type'] as String?) ?? 'payment';
            final notes = (data['notes'] as String?) ?? '';
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Rs ${amount.toStringAsFixed(0)} • ${type.replaceAll('_', ' ')}'),
              subtitle: Text('${DateFormat('dd MMM yyyy').format(date)}${notes.isNotEmpty ? '  •  $notes' : ''}'),
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
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
