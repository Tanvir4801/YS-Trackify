import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import 'labour/my_attendance_screen.dart';
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
      // Wait for Firebase Auth to restore session (critical on web)
      User? user = _auth.currentUser;
      if (user == null) {
        user = await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,
        );
      }

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

      final phone = _digitsOnly(
          (data['phone'] as String?) ?? user.phoneNumber ?? '');
      final userName = (data['name'] as String? ?? 'Labour').trim();
      var labourId = (data['labourId'] as String? ?? '').trim();
      var supervisorId = (data['supervisorId'] as String? ?? '').trim();
      var contractorId = (data['contractorId'] as String? ?? '').trim();

      // Try to find labour by phone if labourId is missing
      if (labourId.isEmpty && phone.length == 10) {
        final labourSnap = await _db
            .collection('labours')
            .where('phone', isEqualTo: phone)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (labourSnap.docs.isEmpty) {
          // Try phoneNumber field too
          final labourSnap2 = await _db
              .collection('labours')
              .where('phoneNumber', isEqualTo: phone)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();
          if (labourSnap2.docs.isNotEmpty) {
            labourId = labourSnap2.docs.first.id;
            supervisorId = (labourSnap2.docs.first
                    .data()['supervisorId'] as String? ??
                '')
                .trim();
            contractorId = (labourSnap2.docs.first
                    .data()['contractorId'] as String? ??
                '')
                .trim();
            await _db.collection('users').doc(user.uid).set({
              'labourId': labourId,
              'supervisorId': supervisorId,
              'contractorId': contractorId,
              'phone': phone,
            }, SetOptions(merge: true));
          }
        } else {
          labourId = labourSnap.docs.first.id;
          supervisorId =
              (labourSnap.docs.first.data()['supervisorId'] as String? ?? '')
                  .trim();
          contractorId =
              (labourSnap.docs.first.data()['contractorId'] as String? ?? '')
                  .trim();
          await _db.collection('users').doc(user.uid).set({
            'labourId': labourId,
            'supervisorId': supervisorId,
            'contractorId': contractorId,
            'phone': phone,
          }, SetOptions(merge: true));
        }
      }

      if (labourId.isEmpty) {
        throw Exception('Labour profile not found. Contact supervisor.');
      }

      // Resolve contractorId if still empty
      if (contractorId.isEmpty) {
        try {
          final labourDoc =
              await _db.collection('labours').doc(labourId).get();
          contractorId =
              (labourDoc.data()?['contractorId'] as String? ?? '').trim();
        } catch (_) {}
      }
      if (contractorId.isEmpty) {
        contractorId =
            SessionService.instance.contractorId ?? supervisorId;
      }

      _session = _LabourSession(
        uid: user.uid,
        phone: phone,
        role: role,
        userName: userName,
        labourId: labourId,
        supervisorId: supervisorId,
        contractorId: contractorId,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
            child: const Text('Logout',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
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
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline,
                      size: 48, color: Colors.red),
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Unable to load labour profile',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loadSession,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabs = <Widget>[
      _LabourDashboardTab(session: session),
      LabourMyAttendanceScreen(
        labourId: session.labourId,
        contractorId: session.contractorId,
      ),
      _LabourPaymentsTab(session: session),
      const QRScreen(showAppBar: false),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          session.userName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) =>
            setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2),
            label: 'My QR',
          ),
        ],
      ),
    );
  }
}

// ─── Session model ─────────────────────────────────────────────────────────

class _LabourSession {
  const _LabourSession({
    required this.uid,
    required this.phone,
    required this.role,
    required this.userName,
    required this.labourId,
    required this.supervisorId,
    required this.contractorId,
  });

  final String uid;
  final String phone;
  final String role;
  final String userName;
  final String labourId;
  final String supervisorId;
  final String contractorId;
}

// ─── Dashboard Tab ─────────────────────────────────────────────────────────

class _LabourDashboardTab extends StatefulWidget {
  const _LabourDashboardTab({required this.session});

  final _LabourSession session;

  @override
  State<_LabourDashboardTab> createState() => _LabourDashboardTabState();
}

class _LabourDashboardTabState extends State<_LabourDashboardTab> {
  final _db = FirebaseFirestore.instance;

  StreamSubscription? _labourSub;
  StreamSubscription? _recordsSub;
  StreamSubscription? _paymentsSub;

  Map<String, dynamic> _labourData = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _attendanceDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _paymentDocs = [];

  @override
  void initState() {
    super.initState();
    _startStreams();
  }

  void _startStreams() {
    final s = widget.session;

    // Labour document stream
    _labourSub = _db
        .collection('labours')
        .doc(s.labourId)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _labourData = snap.data() ?? {});
    });

    // Monthly attendance from nested path (collectionGroup)
    _recordsSub = _db
        .collectionGroup('records')
        .where('labourId', isEqualTo: s.labourId)
        .where('contractorId', isEqualTo: s.contractorId)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _attendanceDocs = snap.docs);
    }, onError: (_) {
      // Fallback: flat attendance collection
      _db
          .collection('attendance')
          .where('labourId', isEqualTo: s.labourId)
          .snapshots()
          .listen((snap) {
        if (mounted) setState(() => _attendanceDocs = snap.docs as List<QueryDocumentSnapshot<Map<String, dynamic>>>);
      });
    });

    // Payments stream
    _paymentsSub = _db
        .collection('payments')
        .where('labourId', isEqualTo: s.labourId)
        .where('contractorId', isEqualTo: s.contractorId)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _paymentDocs = snap.docs);
    }, onError: (_) {
      _db
          .collection('payments')
          .where('labourId', isEqualTo: s.labourId)
          .snapshots()
          .listen((snap) {
        if (mounted) setState(() => _paymentDocs = snap.docs as List<QueryDocumentSnapshot<Map<String, dynamic>>>);
      });
    });
  }

  @override
  void dispose() {
    _labourSub?.cancel();
    _recordsSub?.cancel();
    _paymentsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final now = DateTime.now();
    final monthPrefix =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    final dailyWage =
        (_labourData['dailyWage'] ?? _labourData['dailyRate'] ?? 0)
            .toDouble();
    final labourName =
        (_labourData['name'] as String?)?.trim().isNotEmpty == true
            ? _labourData['name'] as String
            : s.userName;
    final labourRole =
        (_labourData['skill'] ?? _labourData['role'] ?? '') as String;

    var present = 0;
    var absent = 0;
    var halfDay = 0;
    var workedDays = 0.0;
    String todayStatus = 'Not marked';

    for (final doc in _attendanceDocs) {
      final data = doc.data();
      final date = (data['date'] as String?) ?? '';
      if (!date.startsWith(monthPrefix)) continue;
      final status = (data['status'] as String?) ?? '';
      if (status == 'present') {
        present++;
        workedDays += 1;
      } else if (status == 'half_day' || status == 'half') {
        halfDay++;
        workedDays += 0.5;
      } else if (status == 'absent') {
        absent++;
      }
      if (date == todayKey) {
        todayStatus = status == 'present'
            ? 'Present'
            : status == 'half_day' || status == 'half'
                ? 'Half Day'
                : status == 'absent'
                    ? 'Absent'
                    : status;
      }
    }

    final gross = workedDays * dailyWage;

    var totalAdvance = 0.0;
    for (final doc in _paymentDocs) {
      final data = doc.data();
      totalAdvance +=
          (data['amount'] as num?)?.toDouble() ?? 0;
    }

    final net = gross - totalAdvance;

    return RefreshIndicator(
      onRefresh: () async {
        _labourSub?.cancel();
        _recordsSub?.cancel();
        _paymentsSub?.cancel();
        _startStreams();
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        child: Text(
                          labourName.isNotEmpty
                              ? labourName[0].toUpperCase()
                              : 'L',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labourName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            if (labourRole.isNotEmpty)
                              Text(
                                labourRole,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                      // Today status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(todayStatus).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white38, width: 1),
                        ),
                        child: Text(
                          todayStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _HeaderStat(
                          label: 'Daily Wage',
                          value: 'Rs ${dailyWage.toStringAsFixed(0)}'),
                      const SizedBox(width: 24),
                      _HeaderStat(
                          label: 'Days Worked',
                          value: workedDays.toStringAsFixed(1)),
                      const SizedBox(width: 24),
                      _HeaderStat(
                          label: 'Net Pay',
                          value: 'Rs ${net.toStringAsFixed(0)}'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'This Month',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // Attendance stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Present',
                    value: '$present',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Absent',
                    value: '$absent',
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Half Day',
                    value: '$halfDay',
                    icon: Icons.timelapse_rounded,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text(
              'Earnings',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            _EarningsCard(
                label: 'Gross Earned',
                value: 'Rs ${gross.toStringAsFixed(0)}',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF0891B2)),
            const SizedBox(height: 10),
            _EarningsCard(
                label: 'Advance Paid',
                value: 'Rs ${totalAdvance.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFFDC2626)),
            const SizedBox(height: 10),
            _EarningsCard(
                label: 'Net Payable',
                value: 'Rs ${net.toStringAsFixed(0)}',
                icon: Icons.verified_rounded,
                color: net >= 0
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'half day':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

// ─── Payments Tab ──────────────────────────────────────────────────────────

class _LabourPaymentsTab extends StatelessWidget {
  const _LabourPaymentsTab({required this.session});

  final _LabourSession session;

  DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
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
        .where('contractorId', isEqualTo: session.contractorId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...(snap.data?.docs ?? const [])]..sort((a, b) =>
            _toDate(b.data()['createdAt'])
                .compareTo(_toDate(a.data()['createdAt'])));

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.payments_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 10),
                Text('No payments found',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final total = docs.fold<double>(
          0,
          (acc, doc) =>
              acc + ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
        );

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF1E40AF).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet,
                          color: Color(0xFF1E40AF), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Advances',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E40AF),
                                fontWeight: FontWeight.w500)),
                        Text(
                          'Rs ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            final data = docs[index - 1].data();
            final date = _toDate(data['createdAt'] ?? data['date']);
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            final notes = (data['notes'] as String?) ?? '';

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
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
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.currency_rupee,
                        color: Colors.red, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rs ${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          notes.isNotEmpty
                              ? notes
                              : 'Advance payment',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yy').format(date),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Reusable widgets ──────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
