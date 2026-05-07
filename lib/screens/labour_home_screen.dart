import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
      // ── STEP 1: Try SharedPreferences first (labour phone login) ──
      final prefs = await SharedPreferences.getInstance();
      final cachedRole     = prefs.getString('role') ?? '';
      final cachedLabourId = prefs.getString('labourId') ?? '';
      final cachedPhone    = prefs.getString('phone') ?? '';
      final cachedName     = prefs.getString('name') ?? 'Labour';
      final cachedSupId    = prefs.getString('supervisorId') ?? '';
      final cachedUid      = prefs.getString('uid') ?? '';

      // ── STEP 2: Also check Firebase Auth (supervisor/OTP login) ──
      final firebaseUser = FirebaseAuth.instance.currentUser;

      // Decide which uid / phone to use
      String uid   = cachedUid.isNotEmpty ? cachedUid
                   : (firebaseUser?.uid ?? '');
      String phone = cachedPhone.isNotEmpty ? cachedPhone
                   : _digitsOnly(firebaseUser?.phoneNumber ?? '');

      // ── STEP 3: If we have a cached labour session, use it directly ──
      if (cachedRole == 'labour' && cachedLabourId.isNotEmpty) {
        // Verify the labour doc still exists and is active
        final labourDoc =
            await _db.collection('labours').doc(cachedLabourId).get();

        if (!labourDoc.exists || labourDoc.data()?['isActive'] != true) {
          throw Exception('Labour profile not found. Contact supervisor.');
        }

        final labourData = labourDoc.data()!;
        final supervisorId = cachedSupId.isNotEmpty
            ? cachedSupId
            : (labourData['supervisorId'] as String? ?? '');
        final contractorId =
            (labourData['contractorId'] as String? ?? supervisorId);
        final name = cachedName.isNotEmpty
            ? cachedName
            : (labourData['name'] as String? ?? 'Labour');

        _session = _LabourSession(
          uid: uid.isNotEmpty ? uid : cachedLabourId,
          phone: phone,
          role: 'labour',
          userName: name,
          labourId: cachedLabourId,
          supervisorId: supervisorId,
          contractorId: contractorId.isNotEmpty ? contractorId : supervisorId,
        );
        return; // done — skip Firestore users lookup
      }

      // ── STEP 4: Fallback — check Firestore users collection ──
      // (handles OTP-based labour login where Firebase Auth user exists)
      if (uid.isEmpty && phone.isEmpty) {
        throw Exception('Not logged in');
      }

      Map<String, dynamic>? userData;

      // Try by uid first
      if (uid.isNotEmpty) {
        final userDoc = await _db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          userData = userDoc.data();
        }
      }

      // Try by phone if uid lookup failed
      if (userData == null && phone.length == 10) {
        final snap = await _db
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          userData = snap.docs.first.data();
          uid = snap.docs.first.id;
        }
      }

      if (userData == null) {
        throw Exception('Not registered. Contact supervisor.');
      }

      final role     = (userData['role'] as String? ?? '').trim();
      final isActive = userData['isActive'] as bool? ?? true;

      if (!isActive) throw Exception('Account disabled.');
      if (role != 'labour') {
        throw Exception('This account is not a labour account.');
      }

      final userName     = (userData['name'] as String? ?? 'Labour').trim();
      var   labourId     = (userData['labourId'] as String? ?? '').trim();
      var   supervisorId = (userData['supervisorId'] as String? ?? '').trim();

      // Resolve labourId via phone if missing
      if (labourId.isEmpty && phone.length == 10) {
        final labourSnap = await _db
            .collection('labours')
            .where('phone', isEqualTo: phone)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (labourSnap.docs.isNotEmpty) {
          labourId    = labourSnap.docs.first.id;
          supervisorId =
              (labourSnap.docs.first.data()['supervisorId'] as String? ?? '')
                  .trim();
          // Persist back
          await _db.collection('users').doc(uid).set({
            'labourId': labourId,
            'supervisorId': supervisorId,
          }, SetOptions(merge: true));
        }
      }

      if (labourId.isEmpty) {
        throw Exception('Labour profile not found. Contact supervisor.');
      }

      // Resolve contractorId
      String contractorId =
          (userData['contractorId'] as String? ?? '').trim();
      if (contractorId.isEmpty) {
        try {
          final labourDoc =
              await _db.collection('labours').doc(labourId).get();
          contractorId =
              (labourDoc.data()?['contractorId'] as String? ?? '').trim();
        } catch (_) {/* ignore */}
      }
      if (contractorId.isEmpty) {
        contractorId = SessionService.instance.contractorId ?? supervisorId;
      }

      // Cache for next launch
      await prefs.setString('role',         'labour');
      await prefs.setString('uid',           uid);
      await prefs.setString('phone',         phone);
      await prefs.setString('name',          userName);
      await prefs.setString('labourId',      labourId);
      await prefs.setString('supervisorId',  supervisorId);
      await prefs.setBool('isLoggedIn',      true);

      _session = _LabourSession(
        uid:          uid,
        phone:        phone,
        role:         role,
        userName:     userName,
        labourId:     labourId,
        supervisorId: supervisorId,
        contractorId: contractorId,
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _digitsOnly(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) return digits.substring(2);
    if (digits.length > 10) return digits.substring(digits.length - 10);
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
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Unable to load labour profile',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loadSession,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _logout,
                  child: const Text('Logout',
                      style: TextStyle(color: Colors.red)),
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
        labourId:     session.labourId,
        contractorId: session.contractorId,
      ),
      _LabourPaymentsTab(session: session),
      const QRScreen(showAppBar: false),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(session.userName),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined), label: 'Attendance'),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined), label: 'Payments'),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined), label: 'QR'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Session model
// ─────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────
// Dashboard tab
// ─────────────────────────────────────────────────────────
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
        final labourData =
            labourSnap.data?.data() ?? <String, dynamic>{};
        final labourName =
            (labourData['name'] as String?)?.trim().isNotEmpty == true
                ? labourData['name'] as String
                : session.userName;
        final dailyWage =
            (labourData['dailyWage'] as num?)?.toDouble() ?? 0;
        final overtimeRate =
            (labourData['overtimeWagePerHour'] as num?)?.toDouble() ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: attendanceStream,
          builder: (context, attendanceSnap) {
            final docs = attendanceSnap.data?.docs ?? const [];
            final now = DateTime.now();
            final monthPrefix =
                '${now.year.toString().padLeft(4, '0')}-'
                '${now.month.toString().padLeft(2, '0')}';

            int present = 0, absent = 0, half = 0;
            double workedDays = 0, totalOT = 0;

            for (final doc in docs) {
              final data   = doc.data();
              final date   = (data['date'] as String?) ?? '';
              if (!date.startsWith(monthPrefix)) continue;
              final status = (data['status'] as String?) ?? '';
              final ot     =
                  (data['overtimeHours'] as num?)?.toDouble() ?? 0;
              totalOT += ot;
              if (status == 'present') { present++; workedDays += 1; }
              else if (status == 'half') { half++;   workedDays += 0.5; }
              else if (status == 'absent') { absent++; }
            }

            final gross       = (workedDays * dailyWage)
                              + (totalOT * overtimeRate);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: paymentsStream,
              builder: (context, paySnap) {
                final payDocs = paySnap.data?.docs ?? const [];
                double advances = 0;
                for (final doc in payDocs) {
                  final d = doc.data();
                  if ((d['type'] as String?) == 'advance') {
                    advances += (d['amount'] as num?)?.toDouble() ?? 0;
                  }
                }
                final net = gross - advances;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header
                    Row(children: [
                      CircleAvatar(
                        radius: 24,
                        child: Text(
                          labourName.isNotEmpty
                              ? labourName[0].toUpperCase()
                              : 'L',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(labourName,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            Text('📞 ${session.phone}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Attendance chips
                    Row(children: [
                      Expanded(child: _StatusChip(
                          label: 'Present', count: present,
                          color: Colors.green)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatusChip(
                          label: 'Absent', count: absent,
                          color: Colors.red)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatusChip(
                          label: 'Half', count: half,
                          color: Colors.orange)),
                    ]),

                    const SizedBox(height: 16),

                    // Wage cards
                    _MetricCard(
                        title: 'Daily Wage',
                        value: '₹ ${dailyWage.toStringAsFixed(0)}'),
                    const SizedBox(height: 10),
                    if (overtimeRate > 0) ...[
                      _MetricCard(
                          title: 'Overtime Rate',
                          value: '₹ ${overtimeRate.toStringAsFixed(0)} / hr'),
                      const SizedBox(height: 10),
                      _MetricCard(
                          title: 'Total OT Hours (This Month)',
                          value: totalOT.toStringAsFixed(1)),
                      const SizedBox(height: 10),
                    ],
                    _MetricCard(
                        title: 'Worked Days (This Month)',
                        value: workedDays.toStringAsFixed(1)),
                    const SizedBox(height: 10),
                    _MetricCard(
                        title: 'Gross (This Month)',
                        value: '₹ ${gross.toStringAsFixed(0)}'),
                    const SizedBox(height: 10),
                    _MetricCard(
                        title: 'Advance Paid',
                        value: '₹ ${advances.toStringAsFixed(0)}'),
                    const SizedBox(height: 10),
                    _MetricCard(
                        title: 'Net Payable',
                        value: '₹ ${net.toStringAsFixed(0)}',
                        highlight: true),
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

// ─────────────────────────────────────────────────────────
// Payments tab  (unchanged logic, minor UI polish)
// ─────────────────────────────────────────────────────────
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
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...(snap.data?.docs ?? const [])]
          ..sort((a, b) => _toDate(b.data()['date'])
              .compareTo(_toDate(a.data()['date'])));

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.payments_outlined,
                    size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text('No payments yet',
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
              return _MetricCard(
                  title: 'Total Payments',
                  value: '₹ ${total.toStringAsFixed(0)}');
            }
            final data   = docs[index - 1].data();
            final date   = _toDate(data['date']);
            final amount = (data['amount'] as num?)?.toDouble() ?? 0;
            final type   = (data['type'] as String?) ?? 'payment';
            final notes  = (data['notes'] as String?) ?? '';
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: CircleAvatar(
                backgroundColor: type == 'advance'
                    ? Colors.orange.shade100
                    : Colors.green.shade100,
                child: Icon(
                  type == 'advance'
                      ? Icons.arrow_upward
                      : Icons.check_circle_outline,
                  color: type == 'advance' ? Colors.orange : Colors.green,
                  size: 20,
                ),
              ),
              title: Text(
                '₹ ${amount.toStringAsFixed(0)}  •  '
                '${type.replaceAll('_', ' ')}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${DateFormat('dd MMM yyyy').format(date)}'
                '${notes.isNotEmpty ? '  •  $notes' : ''}',
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    this.highlight = false,
  });

  final String title;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
              : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: highlight
                      ? Theme.of(context).colorScheme.primary
                      : null)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: highlight
                      ? Theme.of(context).colorScheme.primary
                      : null)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(
      {required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      ),
    );
  }
}
