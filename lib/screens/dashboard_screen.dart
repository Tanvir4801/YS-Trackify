import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../models/attendance_session_model.dart';
import '../models/site_model.dart';
import '../providers/dashboard_provider.dart';
import '../providers/site_data_provider.dart';
import '../providers/sites_provider.dart';
import '../screens/scanner/session_scanner_screen.dart';
import '../services/attendance_session_service.dart';
import '../services/session_service.dart';
import '../widgets/animations/bouncy_tap.dart';
import '../widgets/animations/count_up_number.dart';
import '../widgets/animations/pulse_badge.dart';
import '../widgets/animations/staggered_list.dart';
import '../widgets/week_attendance_strip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirebaseFirestore.instance;
  final _sessionSvc = AttendanceSessionService();
  StreamSubscription? _attendanceSub;
  StreamSubscription? _labourSub;
  StreamSubscription? _sessionsSub;

  Map<String, Map<String, dynamic>> _supervisorLabours = {};
  Map<String, Map<String, dynamic>> _contractorLabours = {};
  Map<String, String> _supervisorAttendance = {};
  Map<String, String> _contractorAttendance = {};
  Map<String, String> _nestedAttendance = {};
  List<AttendanceSession> _todaySessions = [];

  int _totalLabours = 0;
  int _presentToday = 0;
  int _absentToday = 0;
  int _halfDayToday = 0;
  double _todayWages = 0;

  String _contractorName = 'My Company';

  @override
  void initState() {
    super.initState();
    _loadContractorName();
    _startStreams();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionSvc.abandonOldSessions();
      context.read<SitesProvider>().load();
    });
  }

  Future<void> _loadContractorName() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('contractorName');
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() => _contractorName = cached);
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final userDoc = await _db.collection('users').doc(uid).get();
      var contractorId = (userDoc.data()?['contractorId'] as String?) ?? '';
      if (contractorId.isEmpty) {
        contractorId = SessionService.instance.contractorId ?? uid;
      }
      final freshName = await _getNameByContractorId(contractorId);
      await prefs.setString('contractorName', freshName);
      if (mounted) setState(() => _contractorName = freshName);
    } catch (e) {
      debugPrint('_loadContractorName error: $e');
    }
  }

  Future<String> _getNameByContractorId(String contractorId) async {
    if (contractorId.isEmpty) return 'My Company';
    try {
      final doc = await _db.collection('contractors').doc(contractorId).get();
      if (doc.exists) return (doc.data()?['name'] as String?) ?? 'My Company';
      final snap = await _db
          .collection('contractors')
          .where('id', isEqualTo: contractorId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return (snap.docs.first.data()['name'] as String?) ?? 'My Company';
      }
    } catch (e) {
      debugPrint('_getNameByContractorId error: $e');
    }
    return 'My Company';
  }

  void _startStreams() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final contractorId = SessionService.instance.contractorId ?? uid;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    context.read<DashboardProvider>().startListening(contractorId: contractorId);

    _labourSub?.cancel();
    _labourSub = _db
        .collection('labours')
        .where('supervisorId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      _supervisorLabours = {for (final doc in snap.docs) doc.id: doc.data()};
      _refreshLabourCounts();
    });

    if (contractorId != uid) {
      _db
          .collection('labours')
          .where('contractorId', isEqualTo: contractorId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snap) {
        _contractorLabours = {for (final doc in snap.docs) doc.id: doc.data()};
        _refreshLabourCounts();
      });
    }

    _attendanceSub?.cancel();
    _attendanceSub = _db
        .collection('attendance')
        .where('supervisorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      _supervisorAttendance = _statusMapFromDocs(snap.docs, today);
      _refreshAttendanceTotals();
    });

    _db
        .collection('attendance')
        .doc(contractorId)
        .collection('dates')
        .doc(today)
        .collection('records')
        .snapshots()
        .listen((snap) {
      _nestedAttendance = {
        for (final doc in snap.docs)
          if (_normalizeStatus(doc.data()['status']).isNotEmpty)
            (doc.data()['labourId'] as String? ?? doc.id):
                _normalizeStatus(doc.data()['status']),
      };
      _refreshAttendanceTotals();
    });

    _sessionsSub?.cancel();
    _sessionsSub = _sessionSvc.streamSessionsForToday().listen((sessions) {
      if (mounted) setState(() => _todaySessions = sessions);
    });
  }

  void _refreshLabourCounts() {
    final merged = <String, Map<String, dynamic>>{}
      ..addAll(_supervisorLabours)
      ..addAll(_contractorLabours);
    if (mounted) setState(() => _totalLabours = merged.length);
  }

  void _refreshAttendanceTotals() {
    final statuses = <String, String>{}
      ..addAll(_supervisorAttendance)
      ..addAll(_contractorAttendance)
      ..addAll(_nestedAttendance);

    int present = 0, absent = 0, halfDay = 0;
    for (final s in statuses.values) {
      if (s == 'present') present++;
      else if (s == 'absent') absent++;
      else if (s == 'half') halfDay++;
    }

    final mergedLabours = <String, Map<String, dynamic>>{}
      ..addAll(_supervisorLabours)
      ..addAll(_contractorLabours);
    double total = 0;
    for (final e in mergedLabours.entries) {
      final s = statuses[e.key] ?? '';
      final rate = _labourRate(e.value);
      if (s == 'present') total += rate;
      else if (s == 'half') total += rate / 2;
    }

    if (!mounted) return;
    setState(() {
      _presentToday = present;
      _absentToday = absent;
      _halfDayToday = halfDay;
      _todayWages = total;
    });
  }

  Map<String, String> _statusMapFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String today) {
    final map = <String, String>{};
    for (final doc in docs) {
      final data = doc.data();
      if (!_matchesToday(data['date'], today)) continue;
      final labourId = (data['labourId'] as String?) ?? doc.id;
      final status = _normalizeStatus(data['status']);
      if (labourId.isNotEmpty && status.isNotEmpty) map[labourId] = status;
    }
    return map;
  }

  bool _matchesToday(dynamic rawDate, String today) {
    if (rawDate is String) return rawDate.trim() == today;
    if (rawDate is Timestamp) return DateFormat('yyyy-MM-dd').format(rawDate.toDate()) == today;
    if (rawDate is DateTime) return DateFormat('yyyy-MM-dd').format(rawDate) == today;
    return false;
  }

  String _normalizeStatus(dynamic raw) {
    final s = (raw?.toString() ?? '').trim().toLowerCase();
    if (s == 'half_day' || s == 'half-day') return 'half';
    if (s == 'present' || s == 'absent' || s == 'half') return s;
    return '';
  }

  double _labourRate(Map<String, dynamic> data) {
    final v = data['dailyWage'] ?? data['dailyRate'] ?? 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _labourSub?.cancel();
    _sessionsSub?.cancel();
    super.dispose();
  }

  Future<void> _onSiteTap(SiteModel site, AttendanceSession? session) async {
    if (session != null && session.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${site.name} session is complete for today.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (session != null && session.isActive) {
      if (session.supervisorId != uid) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Session In Progress'),
            content: Text(
              'An active session for ${site.name} is managed by ${session.supervisorName}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScannerScreen(session: session),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start Session'),
        content: Text('Start attendance session for ${site.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final supervisorName = (await _db.collection('users').doc(uid).get())
              .data()?['name'] as String? ?? 'Supervisor';

      final newSession = await _sessionSvc.startSession(
        siteId: site.id,
        siteName: site.name,
        supervisorName: supervisorName,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScannerScreen(session: newSession),
        ),
      );
    } on SessionConflictException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Session Conflict'),
          content: Text(
              '${site.name} already has an active session by ${e.existingSession.supervisorName}.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start session: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteDataProvider>(
      builder: (context, data, _) {
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            _loadContractorName();
            _startStreams();
            final contractorId = SessionService.instance.contractorId ??
                FirebaseAuth.instance.currentUser?.uid ?? '';
            if (contractorId.isNotEmpty) {
              context.read<SiteDataProvider>().startLabourStream(contractorId);
              context.read<SitesProvider>().load();
            }
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildHero(),
              const SizedBox(height: 20),
              _buildOverviewGrid(),
              const SizedBox(height: 24),
              _buildSiteSessionCards(),
              _buildWeekStrip(),
              _buildWageSection(data),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ── Dark navy hero header ─────────────────────────────────────────────────

  Widget _buildHero() {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final emoji = hour < 12 ? '🌤' : hour < 17 ? '👋' : '🌙';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('$greeting  $emoji',
                      style: const TextStyle(
                          color: AppColors.textOnDarkMuted, fontSize: 14)),
                ]),
                const SizedBox(height: 4),
                Text(
                  _contractorName.isEmpty ? 'Loading…' : _contractorName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _formattedToday(),
                  style: const TextStyle(
                      color: AppColors.textOnDarkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.business_rounded,
                color: AppColors.navy, size: 24),
          ),
        ],
      ),
    );
  }

  // ── 2×2 stat overview ─────────────────────────────────────────────────────

  Widget _buildOverviewGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Overview",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: StaggeredFadeIn(
                index: 0,
                child: _overviewCard(
                  icon: Icons.groups_rounded,
                  iconColor: AppColors.blue,
                  iconBg: AppColors.blueBg,
                  label: 'Total Labour',
                  value: _totalLabours,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StaggeredFadeIn(
                index: 1,
                child: _overviewCard(
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.present,
                  iconBg: AppColors.presentSurface,
                  label: 'Present Today',
                  value: _presentToday,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: StaggeredFadeIn(
                index: 2,
                child: _overviewCard(
                  icon: Icons.cancel_rounded,
                  iconColor: AppColors.absent,
                  iconBg: AppColors.absentSurface,
                  label: 'Absent Today',
                  value: _absentToday,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StaggeredFadeIn(
                index: 3,
                child: _overviewCard(
                  icon: Icons.timelapse_rounded,
                  iconColor: AppColors.halfDay,
                  iconBg: AppColors.halfSurface,
                  label: 'Half Day',
                  value: _halfDayToday,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _overviewCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          CountUpNumber(
            value: value,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  // ── Today's Sites ─────────────────────────────────────────────────────────

  Widget _buildSiteSessionCards() {
    return Consumer<SitesProvider>(
      builder: (context, sitesProvider, _) {
        final sites = sitesProvider.sites.where((s) => s.isActive).toList();
        if (sites.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Text("Today's Sites",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('${sites.length}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 12),
              ...sites.asMap().entries.map((e) {
                final i = e.key;
                final site = e.value;
                final session = _todaySessions
                    .cast<AttendanceSession?>()
                    .firstWhere((s) => s!.siteId == site.id, orElse: () => null);
                return StaggeredFadeIn(
                  index: i + 4,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SiteSessionCard(
                      site: site,
                      session: session,
                      onTap: () => _onSiteTap(site, session),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── Week Strip ────────────────────────────────────────────────────────────

  Widget _buildWeekStrip() {
    return Consumer<DashboardProvider>(
      builder: (context, dash, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Last 7 Days',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            WeekAttendanceStrip(attendanceByDate: dash.weekAttendance),
          ],
        ),
      ),
    );
  }

  // ── Wage Snapshot ─────────────────────────────────────────────────────────

  Widget _buildWageSection(SiteDataProvider data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wage Snapshot',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _wageCard(
              label: 'Today',
              amount: _todayWages,
              icon: Icons.today_rounded,
              color: const Color(0xFF0891B2),
              subtitle: 'Based on today\'s attendance'),
          const SizedBox(height: 10),
          _wageCard(
              label: 'This Week',
              amount: data.weekWageTotal,
              icon: Icons.date_range_rounded,
              color: AppColors.gold),
          const SizedBox(height: 10),
          _wageCard(
              label: 'This Month',
              amount: data.monthWageTotal,
              icon: Icons.calendar_month_rounded,
              color: AppColors.present),
        ],
      ),
    );
  }

  Widget _wageCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amount),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (ctx, val, _) => Text(
              '₹${val.toStringAsFixed(0)}',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formattedToday() {
    final now = DateTime.now();
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month]} ${now.year}';
  }
}

// ── Site session card ──────────────────────────────────────────────────────────

class _SiteSessionCard extends StatelessWidget {
  const _SiteSessionCard({
    required this.site,
    required this.session,
    required this.onTap,
  });

  final SiteModel site;
  final AttendanceSession? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = session?.status;
    final isActive = status == SessionStatus.active;
    final isCompleted = status == SessionStatus.completed;
    final isPending = session == null;

    Widget badge;
    if (isPending) {
      badge = PulseBadge(
        label: 'PENDING',
        color: AppColors.goldDark,
        bgColor: AppColors.goldLight.withValues(alpha: 0.28),
      );
    } else if (isActive) {
      badge = PulseBadge(
        label: 'IN PROGRESS',
        color: AppColors.present,
        bgColor: AppColors.presentSurface,
      );
    } else {
      badge = const Icon(Icons.check_circle_rounded,
          color: AppColors.present, size: 20);
    }

    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.present.withValues(alpha: 0.4)
                : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: AppColors.present.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.goldLight.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.goldDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(site.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  session != null
                      ? '${session!.markedCount} marked today'
                      : isCompleted
                          ? 'Completed'
                          : 'Tap to start session',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          badge,
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary, size: 18),
        ]),
      ),
    );
  }
}
