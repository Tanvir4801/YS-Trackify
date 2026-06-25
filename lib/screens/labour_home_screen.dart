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
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRole = prefs.getString('role');
      final cachedLabourId = prefs.getString('labourId');

      if (cachedRole == 'labour' && cachedLabourId != null && cachedLabourId.isNotEmpty) {
        try {
          final labourDoc = await _db.collection('labours').doc(cachedLabourId).get();
          if (labourDoc.exists) {
            final labourData = labourDoc.data()!;
            final isActive = labourData['isActive'] as bool? ?? true;
            if (!isActive) { await prefs.clear(); throw Exception('Account disabled.'); }
            final name         = (labourData['name']         as String? ?? 'Labour').trim();
            final phone        = _digitsOnly((labourData['phone'] as String?) ?? '');
            final supervisorId = (labourData['supervisorId'] as String? ?? '').trim();
            final contractorId = (labourData['contractorId'] as String? ?? '').trim();
            _session = _LabourSession(
              uid: cachedLabourId, phone: phone, role: 'labour',
              userName: name, labourId: cachedLabourId,
              supervisorId: supervisorId, contractorId: contractorId,
            );
            if (mounted) setState(() => _loading = false);
            return;
          }
        } catch (e) {
          debugPrint('Failed to restore cached labour session: $e');
          await prefs.clear();
        }
      }

      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      if (user == null) {
        try {
          user = await auth.authStateChanges()
              .where((u) => u != null).first
              .timeout(const Duration(seconds: 12));
        } catch (_) { user = null; }
      }
      if (user == null) throw Exception('Not logged in — please sign in again');

      var uid   = user.uid;
      var phone = _digitsOnly(user.phoneNumber ?? '');
      Map<String, dynamic>? userData;

      if (uid.isNotEmpty) {
        final userDoc = await _db.collection('users').doc(uid).get();
        if (userDoc.exists) userData = userDoc.data();
      }
      if (userData == null && phone.length == 10) {
        final snap = await _db.collection('users')
            .where('phone', isEqualTo: phone).limit(1).get();
        if (snap.docs.isNotEmpty) { userData = snap.docs.first.data(); uid = snap.docs.first.id; }
      }
      if (userData == null) throw Exception('Not registered. Contact supervisor.');

      final role     = (userData['role']     as String? ?? '').trim();
      final isActive = userData['isActive']  as bool? ?? true;
      if (!isActive) throw Exception('Account disabled.');
      if (role != 'labour') throw Exception('This account is not a labour account.');

      final userName = (userData['name'] as String? ?? 'Labour').trim();
      var labourId     = (userData['labourId']     as String? ?? '').trim();
      var supervisorId = (userData['supervisorId'] as String? ?? '').trim();
      var contractorId = (userData['contractorId'] as String? ?? '').trim();

      if (labourId.isEmpty && phone.length == 10) {
        final labourSnap = await _db.collection('labours')
            .where('phone', isEqualTo: phone).where('isActive', isEqualTo: true).limit(1).get();
        if (labourSnap.docs.isEmpty) {
          final labourSnap2 = await _db.collection('labours')
              .where('phoneNumber', isEqualTo: phone).where('isActive', isEqualTo: true).limit(1).get();
          if (labourSnap2.docs.isNotEmpty) {
            labourId     = labourSnap2.docs.first.id;
            supervisorId = (labourSnap2.docs.first.data()['supervisorId'] as String? ?? '').trim();
            contractorId = (labourSnap2.docs.first.data()['contractorId'] as String? ?? '').trim();
            await _db.collection('users').doc(user.uid).set(
              {'labourId': labourId, 'supervisorId': supervisorId, 'contractorId': contractorId, 'phone': phone},
              SetOptions(merge: true));
          }
        } else {
          labourId     = labourSnap.docs.first.id;
          supervisorId = (labourSnap.docs.first.data()['supervisorId'] as String? ?? '').trim();
          contractorId = (labourSnap.docs.first.data()['contractorId'] as String? ?? '').trim();
          await _db.collection('users').doc(user.uid).set(
            {'labourId': labourId, 'supervisorId': supervisorId, 'contractorId': contractorId, 'phone': phone},
            SetOptions(merge: true));
        }
      }
      if (labourId.isEmpty) throw Exception('Labour profile not found. Contact supervisor.');

      if (contractorId.isEmpty) {
        try {
          final labourDoc = await _db.collection('labours').doc(labourId).get();
          contractorId = (labourDoc.data()?['contractorId'] as String? ?? '').trim();
        } catch (_) {}
      }
      if (contractorId.isEmpty) contractorId = SessionService.instance.contractorId ?? supervisorId;

      await prefs.setString('role',        'labour');
      await prefs.setString('uid',          uid);
      await prefs.setString('phone',        phone);
      await prefs.setString('name',         userName);
      await prefs.setString('labourId',     labourId);
      await prefs.setString('supervisorId', supervisorId);
      await prefs.setBool('isLoggedIn',     true);

      _session = _LabourSession(
        uid: uid, phone: phone, role: role, userName: userName,
        labourId: labourId, supervisorId: supervisorId, contractorId: contractorId,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: AppColors.absent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.navy)));
    }

    final session = _session;
    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('Labour Home'),
          actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.absentBg, shape: BoxShape.circle),
                child: const Icon(Icons.error_outline, size: 40, color: AppColors.absent)),
              const SizedBox(height: 16),
              Text(_error ?? 'Unable to load labour profile',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadSession,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy)),
            ]),
          ),
        ),
      );
    }

    final tabs = <Widget>[
      const QRScreen(showAppBar: false),
      _LabourDashboardTab(session: session),
      LabourMyAttendanceScreen(
        labourId: session.labourId, contractorId: session.contractorId),
      LabourReportTab(
        labourId: session.labourId, contractorId: session.contractorId),
    ];

    const navItems = [
      (Icons.qr_code_2_outlined,  Icons.qr_code_2_rounded,  'My QR'),
      (Icons.dashboard_outlined,  Icons.dashboard_rounded,   'Dashboard'),
      (Icons.fact_check_outlined, Icons.fact_check_rounded,  'Attendance'),
      (Icons.bar_chart_outlined,  Icons.bar_chart_rounded,   'Report'),
    ];

    final initials = session.userName.isNotEmpty ? session.userName[0].toUpperCase() : 'L';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, Color(0xFF1A2438)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(children: [
                // Premium avatar
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDark],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: Text(initials,
                      style: const TextStyle(
                        color: AppColors.navy, fontWeight: FontWeight.w900,
                        fontSize: 20, letterSpacing: -0.5)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_greeting(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    Text(session.userName,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(DateFormat('EEEE, dd MMM').format(DateTime.now()),
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.8),
                        fontSize: 10, fontWeight: FontWeight.w500)),
                  ])),
                // Logout
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: Icon(Icons.logout_rounded, size: 18,
                      color: Colors.white.withValues(alpha: 0.5)))),
              ]),
            ),
          ),
        ),
      ),
      body: ConnectivityBanner(
        child: IndexedStack(index: _tabIndex, children: tabs)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16, offset: const Offset(0, -3))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: List.generate(navItems.length, (i) {
                final (icon, selIcon, label) = navItems[i];
                final sel = _tabIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _tabIndex = i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(sel ? selIcon : icon,
                        size: 23,
                        color: sel ? AppColors.navy : AppColors.textTertiary),
                      const SizedBox(height: 3),
                      Text(label, style: TextStyle(
                        fontSize: 10,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel ? AppColors.navy : AppColors.textTertiary)),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 3, width: sel ? 20 : 0,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(2))),
                    ]),
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

// ─── Session model ────────────────────────────────────────────────────────────

class _LabourSession {
  const _LabourSession({
    required this.uid, required this.phone, required this.role,
    required this.userName, required this.labourId,
    required this.supervisorId, required this.contractorId,
  });

  final String uid;
  final String phone;
  final String role;
  final String userName;
  final String labourId;
  final String supervisorId;
  final String contractorId;
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

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
  final Map<String, Map<String, dynamic>> _flatAttDocs   = {};
  final Map<String, Map<String, dynamic>> _nestedAttDocs = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _paymentDocs = [];

  @override
  void initState() { super.initState(); _startStreams(); }

  void _startStreams() {
    _labourSub?.cancel();
    _flatAttendanceSub?.cancel();
    _nestedAttendanceSub?.cancel();
    _paymentsSub?.cancel();

    final s = widget.session;

    _labourSub = _db.collection('labours').doc(s.labourId).snapshots().listen(
      (snap) { if (mounted) setState(() => _labourData = snap.data() ?? {}); },
      onError: (e) => debugPrint('[DashTab] labourSub error: $e'));

    _flatAttendanceSub = _db.collection('attendance')
        .where('labourId', isEqualTo: s.labourId).snapshots().listen((snap) {
      if (!mounted) return;
      _flatAttDocs.clear();
      for (final doc in snap.docs) {
        final data = doc.data();
        final date = (data['date'] as String?) ?? '';
        if (date.isNotEmpty) _flatAttDocs['${s.labourId}_$date'] = data;
      }
      if (mounted) setState(() {});
    }, onError: (e) => debugPrint('[DashTab] flatAtt error: $e'));

    _nestedAttendanceSub = _db.collectionGroup('records')
        .where('labourId', isEqualTo: s.labourId).snapshots().listen((snap) {
      if (!mounted) return;
      _nestedAttDocs.clear();
      for (final doc in snap.docs) {
        final data    = doc.data();
        final date    = (data['date']     as String?) ?? '';
        final lId     = (data['labourId'] as String?) ?? '';
        if (date.isNotEmpty && lId.isNotEmpty) _nestedAttDocs['${lId}_$date'] = data;
      }
      if (mounted) setState(() {});
    }, onError: (e) => debugPrint('[DashTab] nestedAtt error (non-critical): $e'));

    _paymentsSub = _db.collection('payments')
        .where('labourId', isEqualTo: s.labourId).snapshots().listen(
      (snap) { if (mounted) setState(() => _paymentDocs = snap.docs); },
      onError: (e) => debugPrint('[DashTab] payments error: $e'));
  }

  Map<String, Map<String, dynamic>> get _mergedAttDocs {
    final merged = <String, Map<String, dynamic>>{};
    merged.addAll(_flatAttDocs);
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
    final monthPrefix = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    final dailyWage  = (_labourData['dailyWage'] ?? _labourData['dailyRate'] ?? 0).toDouble();
    final labourName = (_labourData['name'] as String?)?.trim().isNotEmpty == true
        ? _labourData['name'] as String : s.userName;
    final labourRole = ((_labourData['skill'] ?? _labourData['role'] ?? '') as String).trim();
    final otRate     = (_labourData['overtimeWagePerHour'] as num?)?.toDouble() ?? 0;

    var present = 0, absent = 0, halfDay = 0;
    var workedDays = 0.0;
    var totalOTHours = 0.0;
    String todayStatus = 'Not Marked';

    for (final data in _mergedAttDocs.values) {
      final date   = (data['date']   as String?) ?? '';
      final status = (data['status'] as String?) ?? '';
      final ot     = (data['overtimeHours'] as num?)?.toDouble() ?? 0;
      if (!date.startsWith(monthPrefix)) continue;
      if (status == 'present') { present++; workedDays += 1; }
      else if (status == 'half_day' || status == 'half') { halfDay++; workedDays += 0.5; }
      else if (status == 'absent') { absent++; }
      totalOTHours += ot;
      if (date == todayKey) {
        todayStatus = status == 'present' ? 'Present'
            : (status == 'half_day' || status == 'half') ? 'Half Day'
            : status == 'absent' ? 'Absent' : status.isNotEmpty ? status : 'Not Marked';
      }
    }

    final gross        = (workedDays * dailyWage) + (totalOTHours * otRate);
    var totalAdvance   = 0.0;
    for (final doc in _paymentDocs) {
      totalAdvance += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    final net = gross - totalAdvance;
    final total = present + absent + halfDay;
    final attRate = total > 0 ? ((present + halfDay * 0.5) / total * 100).round() : 0;

    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () async {
        _startStreams();
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Premium Hero Card ──────────────────────────────────────────
          _HeroCard(
            labourName: labourName,
            labourRole: labourRole,
            dailyWage: dailyWage,
            workedDays: workedDays,
            net: net,
            todayStatus: todayStatus,
          ),
          const SizedBox(height: 20),

          // ── This Month section label ───────────────────────────────────
          const _SectionLabel('This Month'),
          const SizedBox(height: 10),

          // ── Attendance stats row ───────────────────────────────────────
          Row(children: [
            Expanded(child: _AttStat(
              label: 'Present', value: '$present',
              icon: Icons.check_circle_rounded, color: AppColors.present)),
            const SizedBox(width: 10),
            Expanded(child: _AttStat(
              label: 'Half Day', value: '$halfDay',
              icon: Icons.schedule_rounded, color: AppColors.halfDay)),
            const SizedBox(width: 10),
            Expanded(child: _AttStat(
              label: 'Absent', value: '$absent',
              icon: Icons.cancel_rounded, color: AppColors.absent)),
          ]),
          const SizedBox(height: 12),

          // Attendance progress bar card
          _AttendanceRateCard(attRate: attRate, workedDays: workedDays, totalOTHours: totalOTHours),
          const SizedBox(height: 20),

          // ── Earnings section ───────────────────────────────────────────
          const _SectionLabel('Earnings'),
          const SizedBox(height: 10),
          _EarningsPanel(
            gross: gross,
            totalAdvance: totalAdvance,
            net: net,
            dailyWage: dailyWage,
          ),
        ]),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        color: AppColors.textTertiary, letterSpacing: 1.0));
  }
}

// ─── Hero Card ────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.labourName, required this.labourRole,
    required this.dailyWage, required this.workedDays,
    required this.net, required this.todayStatus,
  });

  final String labourName;
  final String labourRole;
  final double dailyWage;
  final double workedDays;
  final double net;
  final String todayStatus;

  Color get _statusColor {
    switch (todayStatus.toLowerCase()) {
      case 'present':  return AppColors.present;
      case 'absent':   return AppColors.absent;
      case 'half day': return AppColors.halfDay;
      default:         return Colors.white38;
    }
  }

  Color get _statusTextColor {
    switch (todayStatus.toLowerCase()) {
      case 'present':  return AppColors.present;
      case 'absent':   return AppColors.absent;
      case 'half day': return AppColors.halfDay;
      default:         return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = net >= 0;
    final initial = labourName.isNotEmpty ? labourName[0].toUpperCase() : 'L';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF1A2438), Color(0xFF202C44)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22), width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.5),
            blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(children: [
        // Background orbs
        Positioned(top: -30, right: -20,
          child: Container(width: 130, height: 130,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.05)))),
        Positioned(bottom: -40, right: 40,
          child: Container(width: 90, height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.04)))),

        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Profile row
            Row(children: [
              // Gold initial avatar
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, AppColors.goldDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text(initial,
                  style: const TextStyle(color: AppColors.navy,
                    fontWeight: FontWeight.w900, fontSize: 22)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(labourName,
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 18),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  labourRole.isNotEmpty ? labourRole : 'Construction Worker',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12, fontWeight: FontWeight.w500)),
              ])),
              // Today badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.3))),
                child: Text(todayStatus, style: TextStyle(
                  color: _statusTextColor, fontSize: 11, fontWeight: FontWeight.w700))),
            ]),

            const SizedBox(height: 20),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),

            // Stats row
            Row(children: [
              Expanded(child: _HeroStat(
                label: 'Daily Wage',
                value: '₹${dailyWage.toStringAsFixed(0)}',
                valueColor: Colors.white)),
              Container(width: 1, height: 40,
                color: Colors.white.withValues(alpha: 0.1)),
              Expanded(child: _HeroStat(
                label: 'Days Worked',
                value: workedDays.toStringAsFixed(1),
                valueColor: AppColors.goldLight)),
              Container(width: 1, height: 40,
                color: Colors.white.withValues(alpha: 0.1)),
              Expanded(child: _HeroStat(
                label: 'Net Payable',
                value: '₹${net.abs().toStringAsFixed(0)}',
                valueColor: isPositive ? AppColors.gold : AppColors.absent,
                isLarge: true)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label, required this.value,
    required this.valueColor, this.isLarge = false,
  });
  final String label;
  final String value;
  final Color valueColor;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(
        color: valueColor, fontWeight: FontWeight.w900,
        fontSize: isLarge ? 20 : 16)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 9, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center),
    ]);
  }
}

// ─── Attendance Stat Chip ─────────────────────────────────────────────────────
class _AttStat extends StatelessWidget {
  const _AttStat({
    required this.label, required this.value,
    required this.icon, required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(
          color: color, fontWeight: FontWeight.w900, fontSize: 22)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
          color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─── Attendance Rate Card ─────────────────────────────────────────────────────
class _AttendanceRateCard extends StatelessWidget {
  const _AttendanceRateCard({
    required this.attRate, required this.workedDays, required this.totalOTHours});
  final int attRate;
  final double workedDays;
  final double totalOTHours;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.insights_rounded, color: AppColors.navy, size: 16),
          const SizedBox(width: 8),
          const Expanded(child: Text('Attendance Rate',
            style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 13, color: AppColors.textPrimary))),
          Text('$attRate%', style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.navy)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: attRate / 100, minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.gold))),
        const SizedBox(height: 12),
        Row(children: [
          _MiniStat(icon: Icons.work_outline_rounded, label: 'Days Worked',
            value: workedDays.toStringAsFixed(1), color: AppColors.navy),
          const SizedBox(width: 16),
          if (totalOTHours > 0)
            _MiniStat(icon: Icons.bolt_rounded, label: 'OT Hours',
              value: '${totalOTHours.toStringAsFixed(1)}h', color: AppColors.halfDay),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label,
    required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 5),
      Text(value, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
        fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }
}

// ─── Earnings Panel ───────────────────────────────────────────────────────────
class _EarningsPanel extends StatelessWidget {
  const _EarningsPanel({
    required this.gross, required this.totalAdvance,
    required this.net, required this.dailyWage,
  });
  final double gross;
  final double totalAdvance;
  final double net;
  final double dailyWage;

  @override
  Widget build(BuildContext context) {
    final isPositive = net >= 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        _ERow(icon: Icons.trending_up_rounded, label: 'Gross Earned',
          value: '₹${gross.toStringAsFixed(0)}', color: AppColors.navy),
        Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
        _ERow(icon: Icons.account_balance_wallet_rounded, label: 'Advance Paid',
          value: '-₹${totalAdvance.toStringAsFixed(0)}', color: AppColors.absent),
        Divider(color: AppColors.border),
        // Net payable highlight
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPositive
                  ? [AppColors.navy, const Color(0xFF1F2B40)]
                  : [AppColors.absent.withValues(alpha: 0.85), AppColors.absent],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: isPositive
                ? Border.all(color: AppColors.gold.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            const Expanded(child: Text('Net Payable',
              style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700, fontSize: 15))),
            Text('₹${net.abs().toStringAsFixed(0)}',
              style: TextStyle(
                color: isPositive ? AppColors.gold : Colors.white,
                fontWeight: FontWeight.w900, fontSize: 24)),
          ]),
        ),
      ]),
    );
  }
}

class _ERow extends StatelessWidget {
  const _ERow({required this.icon, required this.label,
    required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600,
            fontSize: 14, color: AppColors.textPrimary))),
        Text(value, style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, color: color)),
      ]),
    );
  }
}
