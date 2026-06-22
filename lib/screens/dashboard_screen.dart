import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/snackbar_utils.dart';
import '../models/attendance_session_model.dart';
import '../models/site_model.dart';
import '../providers/closing_report_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/site_data_provider.dart';
import '../providers/sites_provider.dart';
import '../providers/branding_provider.dart';
import '../providers/attendance_provider.dart';
import '../screens/scanner/session_scanner_screen.dart';
import '../screens/settings/app_info_screen.dart';
import '../screens/notice_board_screen.dart';
import '../core/utils/haptic_utils.dart';
import '../core/localization/app_text.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/attendance_session_service.dart';
import '../services/session_service.dart';
import '../widgets/animations/staggered_list.dart';
import '../widgets/today_summary_card.dart';
import '../widgets/week_attendance_strip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirebaseFirestore.instance;
  final _sessionSvc = AttendanceSessionService();
  StreamSubscription? _sessionsSub;

  List<AttendanceSession> _todaySessions = [];

  String _contractorName = 'My Company';

  @override
  void initState() {
    super.initState();
    _loadContractorName();
    _startStreams();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sessionSvc.abandonOldSessions();

      // Ensure contractorId is available before loading Sites.
      // SitesService.fetchSites() depends on SessionService.instance.contractorId,
      // otherwise it may fetch for the wrong scope and show no active sites.
      final contractorId = SessionService.instance.contractorId;
      if (contractorId == null || contractorId.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      if (!mounted) return;
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
      if (mounted) {
        setState(() => _contractorName = freshName);
        context.read<BrandingProvider>().loadBranding(contractorId, freshName);
      }
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
    context.read<SiteDataProvider>().startLabourStream(contractorId);

    _sessionsSub?.cancel();
    _sessionsSub = _sessionSvc.streamSessionsForToday().listen((sessions) {
      if (mounted) setState(() => _todaySessions = sessions);
    });
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
    _sessionsSub?.cancel();
    super.dispose();
  }

  Future<void> _onSiteTap(SiteModel site, AttendanceSession? session) async {
    if (session != null && session.isCompleted) {
      AppSnackBar.showSuccess(context, 'Generating report for ${site.name}...');
      final reportProvider = context.read<ClosingReportProvider>();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      await reportProvider.generateReport(siteId: site.id, siteName: site.name, date: today);
      if (reportProvider.error == null && mounted) {
        await reportProvider.saveReport();
        reportProvider.downloadPdf();
      } else if (mounted) {
        AppSnackBar.showError(context, reportProvider.error ?? 'Failed to generate report.');
      }
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start', style: TextStyle(fontWeight: FontWeight.w600)),
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
      AppSnackBar.showError(context, 'Failed to start session: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<SiteDataProvider, DashboardProvider>(
      builder: (context, data, dash, _) {
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
              _buildOverviewGrid(data, dash),
              const SizedBox(height: 24),
              _buildSiteSessionCards(),
              const SizedBox(height: 24),
              _buildClosingReportCard(data),
              _buildWeekStrip(dash),
              _buildWageSection(data, dash),
              const SizedBox(height: 180),
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

    return Consumer<BrandingProvider>(
      builder: (ctx, brand, _) {
        final b = brand.branding;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
          decoration: BoxDecoration(
            color: b.themeColorDark,
            borderRadius: const BorderRadius.only(
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
                    Row(
                      children: [
                        if (b.logoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              b.logoUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: b.themeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: b.themeColor.withValues(alpha: 0.3)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              b.companyName.isNotEmpty ? b.companyName.substring(0, 1).toUpperCase() : 'M',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: b.themeColorLight,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('$greeting  $emoji',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textOnDarkMuted, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      b.companyName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formattedToday(),
                      style: const TextStyle(
                          color: AppColors.textOnDarkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.campaign_rounded, color: AppColors.gold),
                    onPressed: () {
                      HapticUtils.light();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NoticeBoardScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                    onPressed: () {
                      HapticUtils.light();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AppInfoScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_outlined, color: Colors.white70),
                    onPressed: _confirmLogout,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    HapticUtils.light();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ctx.tr('logout')),
          content: Text(ctx.tr('logoutConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('cancel'),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.absent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) return;

    final navigator = Navigator.of(context);
    await AuthService().logout();
    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  // ── 2×2 stat overview ─────────────────────────────────────────────────────

  Widget _buildOverviewGrid(SiteDataProvider data, DashboardProvider dash) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TodaySummaryCard(
        totalLabour: dash.totalLabour,
        present: dash.presentToday,
        absent: dash.absentToday,
        halfDay: dash.halfToday,
        grossPayable: data.todayWageTotal,
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Today's Sites ─────────────────────────────────────────────────────────

  Widget _buildSiteSessionCards() {
    return Consumer2<SitesProvider, AttendanceProvider>(
      builder: (context, sitesProvider, attendanceProvider, _) {
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
                int labourCount = 0;
                double siteCost = 0;
                for (final summary in attendanceProvider.dailyShiftMap.values) {
                  final thisSiteVisit = summary.siteVisits.where((v) => v.siteId == site.id).firstOrNull;
                  if (thisSiteVisit != null && thisSiteVisit.factor > 0) {
                    labourCount++;
                    final l = attendanceProvider.labours.where((l) => l.id == summary.labourId).firstOrNull;
                    if (l != null) {
                      siteCost += l.dailyWage * thisSiteVisit.factor;
                    }
                  }
                }

                return StaggeredFadeIn(
                  index: i + 4,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SiteSessionCard(
                      site: site,
                      session: session,
                      labourCount: labourCount,
                      siteCost: siteCost,
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

  // ── Daily Closing Report Card ─────────────────────────────────────────────

  Widget _buildClosingReportCard(SiteDataProvider data) {
    return Consumer<ClosingReportProvider>(
      builder: (context, reportProvider, _) {
        final isGenerating = reportProvider.isGenerating;
        final hasReport = reportProvider.currentReport != null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.navy,
                  AppColors.navy.withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daily Site Closing Report',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasReport ? AppColors.present.withValues(alpha: 0.2) : AppColors.goldDark.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(hasReport ? 'Attendance Completed' : 'Pending',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: hasReport ? AppColors.present : AppColors.goldDark)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Total Expense Big Display
                const Text('Total Expense', style: TextStyle(color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('₹${data.todayWageTotal.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.gold, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
                
                const SizedBox(height: 24),
                
                // Today's Insights Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.insights_rounded, color: AppColors.gold, size: 16),
                          SizedBox(width: 8),
                          Text("Today's Insights", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _insightBullet('Attendance improved by 15%'),
                      const SizedBox(height: 8),
                      _insightBullet('No issues detected'),
                      const SizedBox(height: 8),
                      _insightBullet('Material expenses are low'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                if (!hasReport)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isGenerating
                          ? null
                          : () async {
                              final sites = context.read<SitesProvider>().sites.where((s) => s.isActive).toList();
                              final siteId = sites.isNotEmpty ? sites.first.id : '';
                              final siteName = sites.isNotEmpty ? sites.first.name : 'All Sites';
                              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

                              await reportProvider.generateReport(siteId: siteId, siteName: siteName, date: today);
                              if (reportProvider.error == null && context.mounted) {
                                await reportProvider.saveReport();
                                AppSnackBar.showSuccess(context, 'Report generated & saved!');
                              } else if (context.mounted) {
                                AppSnackBar.showError(context, reportProvider.error ?? 'Failed to generate report.');
                              }
                            },
                      icon: isGenerating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                          : const Icon(Icons.description_rounded, size: 20),
                      label: Text(isGenerating ? 'Generating...' : 'Generate Report',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => reportProvider.downloadPdf(),
                              icon: const Icon(Icons.visibility_rounded, size: 18),
                              label: const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success, // WhatsApp Green
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => reportProvider.shareWhatsApp(),
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: const Text('Share WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppColors.textTertiary),
                          onPressed: () => reportProvider.downloadPdf(),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _insightBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 8),
          child: Icon(Icons.circle, color: AppColors.gold, size: 6),
        ),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }

  // ── Week Strip ────────────────────────────────────────────────────────────

  Widget _buildWeekStrip(DashboardProvider dash) {
    return Padding(
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
    );
  }

  // ── Wage Snapshot ─────────────────────────────────────────────────────────

  Widget _buildWageSection(SiteDataProvider data, DashboardProvider dash) {
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
              amount: data.todayWageTotal,
              icon: Icons.today_rounded,
              color: AppColors.blue,
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
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
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
    required this.labourCount,
    required this.siteCost,
    required this.onTap,
  });

  final SiteModel site;
  final AttendanceSession? session;
  final int labourCount;
  final double siteCost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = session?.status;
    final isActive = status == SessionStatus.active;
    final isCompleted = status == SessionStatus.completed;
    final isPending = session == null;

    final statusText = isPending ? 'Pending' : (isActive ? 'In Progress' : 'Completed');
    final statusColor = isPending ? AppColors.goldDark : (isActive ? AppColors.blue : AppColors.present);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.goldLight.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: AppColors.goldDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(site.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          
          const Divider(color: AppColors.surfaceElevated, height: 1, indent: 16, endIndent: 16),
          
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detailRow('Total Labour', '$labourCount Labour'),
                const SizedBox(height: 8),
                _detailRow("Today's Cost", '₹${siteCost.toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Attendance', style: TextStyle(color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(statusText, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onTap,
                child: Text(isPending ? 'Start Attendance' : (isActive ? 'Resume Session' : 'Generate Report'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          
          // Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                _chip('$labourCount Labour'),
                const SizedBox(width: 8),
                _chip('₹${siteCost.toStringAsFixed(0)}'),
                const SizedBox(width: 8),
                _chip(isActive ? 'Active' : (isCompleted ? 'Done' : 'Pending'), color: statusColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _chip(String text, {Color color = AppColors.textTertiary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
