import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/dashboard_provider.dart';
import '../providers/site_data_provider.dart';
import '../services/session_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/week_attendance_strip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _attendanceSub;
  StreamSubscription? _labourSub;

  Map<String, Map<String, dynamic>> _supervisorLabours = {};
  Map<String, Map<String, dynamic>> _contractorLabours = {};
  Map<String, String> _supervisorAttendance = {};
  Map<String, String> _contractorAttendance = {};
  Map<String, String> _nestedAttendance = {};

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
      if (doc.exists) {
        return (doc.data()?['name'] as String?) ?? 'My Company';
      }
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

    _labourSub?.cancel();
    _labourSub = _db
        .collection('labours')
        .where('supervisorId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      _supervisorLabours = {
        for (final doc in snap.docs) doc.id: doc.data(),
      };
      _refreshLabourCounts();
    });

    if (contractorId != uid) {
      _db
          .collection('labours')
          .where('contractorId', isEqualTo: contractorId)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snap) {
        _contractorLabours = {
          for (final doc in snap.docs) doc.id: doc.data(),
        };
        _refreshLabourCounts();
      });
    } else {
      _contractorLabours = {};
    }

    _attendanceSub?.cancel();
    _attendanceSub = _db
        .collection('attendance')
        .where('supervisorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      _supervisorAttendance = _attendanceStatusMapFromDocs(snap.docs, today);
      _refreshAttendanceTotals();
    });

    if (contractorId != uid) {
      _db
          .collection('attendance')
          .where('contractorId', isEqualTo: contractorId)
          .snapshots()
          .listen((snap) {
        _contractorAttendance = _attendanceStatusMapFromDocs(snap.docs, today);
        _refreshAttendanceTotals();
      });
    } else {
      _contractorAttendance = {};
    }

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
  }

  void _refreshLabourCounts() {
    final merged = <String, Map<String, dynamic>>{}
      ..addAll(_supervisorLabours)
      ..addAll(_contractorLabours);
    if (mounted) {
      setState(() => _totalLabours = merged.length);
    }
  }

  void _refreshAttendanceTotals() {
    final mergedStatuses = <String, String>{}
      ..addAll(_supervisorAttendance)
      ..addAll(_contractorAttendance)
      ..addAll(_nestedAttendance);

    int present = 0;
    int absent = 0;
    int halfDay = 0;

    for (final status in mergedStatuses.values) {
      switch (status) {
        case 'present':
          present++;
          break;
        case 'absent':
          absent++;
          break;
        case 'half':
          halfDay++;
          break;
      }
    }

    final mergedLabours = <String, Map<String, dynamic>>{}
      ..addAll(_supervisorLabours)
      ..addAll(_contractorLabours);

    double total = 0;
    for (final entry in mergedLabours.entries) {
      final labourId = entry.key;
      final labourData = entry.value;
      final status = mergedStatuses[labourId] ?? '';
      final rate = _labourRate(labourData);
      if (status == 'present') {
        total += rate;
      } else if (status == 'half') {
        total += rate / 2;
      }
    }

    if (!mounted) return;
    setState(() {
      _presentToday = present;
      _absentToday = absent;
      _halfDayToday = halfDay;
      _todayWages = total;
    });
  }

  Map<String, String> _attendanceStatusMapFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String today,
  ) {
    final map = <String, String>{};
    for (final doc in docs) {
      final data = doc.data();
      final dateValue = data['date'];
      if (!_matchesToday(dateValue, today)) continue;

      final labourId = (data['labourId'] as String?) ?? doc.id;
      final status = _normalizeStatus(data['status']);
      if (labourId.isNotEmpty && status.isNotEmpty) {
        map[labourId] = status;
      }
    }
    return map;
  }

  bool _matchesToday(dynamic rawDate, String today) {
    if (rawDate is String) {
      return rawDate.trim() == today;
    }
    if (rawDate is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(rawDate.toDate()) == today;
    }
    if (rawDate is DateTime) {
      return DateFormat('yyyy-MM-dd').format(rawDate) == today;
    }
    return false;
  }

  String _normalizeStatus(dynamic rawStatus) {
    final status = (rawStatus?.toString() ?? '').trim().toLowerCase();
    if (status == 'half_day' || status == 'half-day') return 'half';
    if (status == 'present' || status == 'absent' || status == 'half') {
      return status;
    }
    return '';
  }

  double _labourRate(Map<String, dynamic> labourData) {
    final value = labourData['dailyWage'] ?? labourData['dailyRate'] ?? 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _labourSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteDataProvider>(
      builder: (context, data, _) {
        return SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _loadContractorName();
              _startStreams();
              final contractorId = SessionService.instance.contractorId ??
                  FirebaseAuth.instance.currentUser?.uid ??
                  '';
              if (contractorId.isNotEmpty) {
                context.read<SiteDataProvider>().startLabourStream(contractorId);
              }
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildStatGrid(),
                  _buildWeekStrip(),
                  _buildWageSection(data),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(
                  _contractorName,
                  style: AppTextStyles.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    return Consumer<DashboardProvider>(
      builder: (context, dash, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Last 7 Days', style: AppTextStyles.headingMedium),
              const SizedBox(height: 12),
              WeekAttendanceStrip(attendanceByDate: dash.weekAttendance),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Overview", style: AppTextStyles.headingMedium),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              StatCard(
                title: 'Total Labour',
                value: '$_totalLabours',
                icon: Icons.people_alt_rounded,
                color: AppColors.accent,
              ),
              StatCard(
                title: 'Present Today',
                value: '$_presentToday',
                icon: Icons.check_circle_rounded,
                color: AppColors.present,
              ),
              StatCard(
                title: 'Absent Today',
                value: '$_absentToday',
                icon: Icons.cancel_rounded,
                color: AppColors.absent,
              ),
              StatCard(
                title: 'Half Day',
                value: '$_halfDayToday',
                icon: Icons.timelapse_rounded,
                color: AppColors.halfDay,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWageSection(SiteDataProvider data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wage Snapshot', style: AppTextStyles.headingMedium),
          const SizedBox(height: 12),
          _buildWageCard(
            label: 'Today',
            amount: _todayWages,
            icon: Icons.today_rounded,
            color: const Color(0xFF0891B2),
            subtitle: 'Based on attendance',
          ),
          const SizedBox(height: 10),
          _buildWageCard(
            label: 'This Week',
            amount: data.weekWageTotal,
            icon: Icons.date_range_rounded,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 10),
          _buildWageCard(
            label: 'This Month',
            amount: data.monthWageTotal,
            icon: Icons.calendar_month_rounded,
            color: AppColors.present,
          ),
        ],
      ),
    );
  }

  Widget _buildWageCard({
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                Text(label, style: AppTextStyles.caption),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
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
}
