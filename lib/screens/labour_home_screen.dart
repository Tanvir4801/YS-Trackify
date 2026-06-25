import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../widgets/offline_banner.dart';
import 'labour/labour_report_tab.dart';
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
      // First, check for cached labour session (labour login doesn't use Firebase Auth)
      final prefs = await SharedPreferences.getInstance();
      final cachedRole = prefs.getString('role');
      final cachedLabourId = prefs.getString('labourId');
      
      if (cachedRole == 'labour' && cachedLabourId != null && cachedLabourId.isNotEmpty) {
        try {
          // Try to restore labour from Firestore
          final labourDoc = await _db.collection('labours').doc(cachedLabourId).get();
          if (labourDoc.exists) {
            final labourData = labourDoc.data()!;
            final isActive = labourData['isActive'] as bool? ?? true;
            
            if (!isActive) {
              await prefs.clear();
              throw Exception('Account disabled.');
            }

            final name = (labourData['name'] as String? ?? 'Labour').trim();
            final phone = _digitsOnly((labourData['phone'] as String?) ?? '');
            final supervisorId = (labourData['supervisorId'] as String? ?? '').trim();
            final contractorId = (labourData['contractorId'] as String? ?? '').trim();
            
            _session = _LabourSession(
              uid: cachedLabourId,
              phone: phone,
              role: 'labour',
              userName: name,
              labourId: cachedLabourId,
              supervisorId: supervisorId,
              contractorId: contractorId,
            );
            if (mounted) {
              setState(() => _loading = false);
            }
            return;
          }
        } catch (e) {
          debugPrint('Failed to restore cached labour session: $e');
          await prefs.clear();
        }
      }

      // Fall back to Firebase Auth user (for supervisors or if cache is invalid)
      // Wait for Firebase Auth to restore persisted session (critical on web).
      // authStateChanges() fires null immediately on web before restoring the
      // session from IndexedDB — we MUST skip null events and wait for the
      // first real user or a 12-second timeout.
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      if (user == null) {
        try {
          user = await auth
              .authStateChanges()
              .where((u) => u != null)
              .first
              .timeout(const Duration(seconds: 12));
        } catch (_) {
          user = null;
        }
      }

      if (user == null) {
        throw Exception('Not logged in — please sign in again');
      }

      var uid = user.uid;
      var phone = _digitsOnly(user.phoneNumber ?? '');
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

      final userName = (userData['name'] as String? ?? 'Labour').trim();
      var labourId = (userData['labourId'] as String? ?? '').trim();
      var supervisorId = (userData['supervisorId'] as String? ?? '').trim();
      var contractorId = (userData['contractorId'] as String? ?? '').trim();

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
      if (mounted) {
        setState(() => _loading = false);
      }
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
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
      const QRScreen(showAppBar: false),
      _LabourDashboardTab(session: session),
      LabourMyAttendanceScreen(
        labourId:     session.labourId,
        contractorId: session.contractorId,
      ),
      LabourReportTab(
        labourId: session.labourId,
        contractorId: session.contractorId,
      ),
    ];

    const _navItems = [
      (Icons.qr_code_2_outlined,   Icons.qr_code_2_rounded,   'My QR'),
      (Icons.dashboard_outlined,   Icons.dashboard_rounded,    'Dashboard'),
      (Icons.fact_check_outlined,  Icons.fact_check_rounded,   'Attendance'),
      (Icons.bar_chart_outlined,   Icons.bar_chart_rounded,    'Report'),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.navyLight],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded, size: 18, color: AppColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(session.userName,
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.2)),
                        const Text('Labour Account',
                          style: TextStyle(fontSize: 11, color: AppColors.textOnDarkMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.textOnDarkMuted),
                    onPressed: _logout,
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ConnectivityBanner(
        child: IndexedStack(index: _tabIndex, children: tabs),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_navItems.length, (i) {
                final (icon, selIcon, label) = _navItems[i];
                final sel = _tabIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); setState(() => _tabIndex = i); },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(sel ? selIcon : icon,
                            size: 22,
                            color: sel ? AppColors.navy : AppColors.textTertiary),
                          const SizedBox(height: 3),
                          Text(label,
                            style: TextStyle(
                              fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                              color: sel ? AppColors.navy : AppColors.textTertiary)),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 3, width: sel ? 18 : 0,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(2))),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
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
  StreamSubscription? _flatAttendanceSub;
  StreamSubscription? _nestedAttendanceSub;
  StreamSubscription? _paymentsSub;

  Map<String, dynamic> _labourData = {};
  // Dual maps for flat + nested; keyed to deduplicate by labour+date
  final Map<String, Map<String, dynamic>> _flatAttDocs = {};
  final Map<String, Map<String, dynamic>> _nestedAttDocs = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _paymentDocs = [];

  @override
  void initState() {
    super.initState();
    _startStreams();
  }

  void _startStreams() {
    // Cancel existing before re-subscribing
    _labourSub?.cancel();
    _flatAttendanceSub?.cancel();
    _nestedAttendanceSub?.cancel();
    _paymentsSub?.cancel();

    final s = widget.session;

    // 1. Labour document — real-time profile + wage data
    _labourSub = _db
        .collection('labours')
        .doc(s.labourId)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _labourData = snap.data() ?? {});
    }, onError: (e) => debugPrint('[DashTab] labourSub error: $e'));

    // 2. Flat attendance collection (primary — always reliable)
    _flatAttendanceSub = _db
        .collection('attendance')
        .where('labourId', isEqualTo: s.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      _flatAttDocs.clear();
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = (data['date'] as String?) ?? '';
        if (date.isNotEmpty) {
          _flatAttDocs['${s.labourId}_$date'] = data;
        }
      }
      if (mounted) setState(() {});
    }, onError: (e) => debugPrint('[DashTab] flatAtt error: $e'));

    // 3. Nested attendance path (supplement — may need Firestore index)
    _nestedAttendanceSub = _db
        .collectionGroup('records')
        .where('labourId', isEqualTo: s.labourId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      _nestedAttDocs.clear();
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = (data['date'] as String?) ?? '';
        final labourId = (data['labourId'] as String?) ?? '';
        if (date.isNotEmpty && labourId.isNotEmpty) {
          // Nested overwrites flat for same date (more authoritative)
          _nestedAttDocs['${labourId}_$date'] = data;
        }
      }
      if (mounted) setState(() {});
    }, onError: (e) {
      // Non-critical — flat collection covers all data
      debugPrint('[DashTab] nestedAtt error (non-critical): $e');
    });

    // 4. Payments — try with contractorId filter, fallback without
    _paymentsSub = _db
        .collection('payments')
        .where('labourId', isEqualTo: s.labourId)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _paymentDocs = snap.docs);
    }, onError: (e) => debugPrint('[DashTab] payments error: $e'));
  }

  // Merged attendance: flat + nested deduplicated
  Map<String, Map<String, dynamic>> get _mergedAttDocs {
    final merged = <String, Map<String, dynamic>>{};
    merged.addAll(_flatAttDocs);
    // Nested takes precedence for the same key
    merged.addAll(_nestedAttDocs);
    return merged;
  }

  @override
  void dispose() {
    _labourSub?.cancel();
    _flatAttendanceSub?.cancel();
    _nestedAttendanceSub?.cancel();
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

    for (final data in _mergedAttDocs.values) {
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
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
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
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
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
                          color: _statusColor(todayStatus).withValues(alpha: 0.25),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
              color: color.withValues(alpha: 0.8),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
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
