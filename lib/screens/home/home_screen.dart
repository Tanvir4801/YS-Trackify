import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/glass_card.dart';
import '../../core/utils/haptic_utils.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../models/attendance_session_model.dart';
import '../../models/site_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/branding_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/site_data_provider.dart';
import '../../providers/sites_provider.dart';
import '../../services/attendance_session_service.dart';
import '../../services/session_service.dart';
import '../../utils/error_handler.dart';

import '../app_shell.dart';
import '../calculator/calculator_screen.dart';
import '../cost_management/site_cost_dashboard_screen.dart';
import '../daily_closing/daily_closing_screen.dart';
import '../notice_board_screen.dart';
import '../scanner/session_scanner_screen.dart';

import 'widgets/action_tile.dart';
import 'widgets/attention_item.dart';
import 'widgets/module_card.dart';
import 'widgets/site_row.dart';
import 'widgets/stat_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

    context
        .read<DashboardProvider>()
        .startListening(contractorId: contractorId);
    context.read<SiteDataProvider>().startLabourStream(contractorId);

    _sessionsSub?.cancel();
    _sessionsSub = _sessionSvc.streamSessionsForToday().listen((sessions) {
      if (mounted) setState(() => _todaySessions = sessions);
    });
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    super.dispose();
  }

  Future<void> _onSiteTap(SiteModel site, AttendanceSession? session) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (session != null && session.isActive) {
      if (session.supervisorId != uid) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondaryColor(context))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryColor(context),
              foregroundColor: AppColors.textOnPrimaryColor(context),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final supervisorName = (await _db.collection('users').doc(uid).get())
              .data()?['name'] as String? ??
          'Supervisor';

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      AppSnackBar.showError(context, ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final attData = context.watch<AttendanceProvider>();
    return Consumer3<SiteDataProvider, DashboardProvider, SitesProvider>(
      builder: (context, data, dash, sitesProvider, _) {
        final sites = sitesProvider.sites.where((s) => s.isActive).toList();
        final pendingSitesCount = sites.where((s) {
          return attData.siteMap[s.id]?.isEmpty ?? true;
        }).length;

        return SafeArea(
          top: true,
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primaryColor(context),
          onRefresh: () async {
            _loadContractorName();
            _startStreams();
            final contractorId = SessionService.instance.contractorId ??
                FirebaseAuth.instance.currentUser?.uid ??
                '';
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
              _buildHeader(sitesProvider),
              const SizedBox(height: 20),
              _buildTodaySummary(dash, data, sites.length, pendingSitesCount),
              const SizedBox(height: 24),
              _buildPrimaryActions(sites, pendingSitesCount),
              const SizedBox(height: 24),
              _buildModuleGrid(),
              const SizedBox(height: 24),
              _buildSitesList(sites),
              const SizedBox(height: 24),
              _buildNeedsAttention(pendingSitesCount),
              const SizedBox(height: 120),
            ],
          ),
        ));
      },
    );
  }

  Widget _buildHeader(SitesProvider siteProvider) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final emoji = hour < 12
        ? '🌤'
        : hour < 17
            ? '👋'
            : '🌙';
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);

    return Consumer<BrandingProvider>(
      builder: (ctx, brand, _) {
        final b = brand.branding;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting $emoji',
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8FA8C2) : AppColors.textSecondaryColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      b.companyName.isEmpty ? _contractorName : b.companyName,
                      style: AppTextStyles.displayMedium.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF4F7FB) : AppColors.textPrimaryColor(context),
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 17,
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF91A7BE) : AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : AppColors.glassSurfaceColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.primaryColor(context).withValues(alpha: 0.4) : AppColors.glassBorderColor(context)),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? [BoxShadow(color: AppColors.primaryColor(context).withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 1)]
                          : null,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.campaign_rounded,
                          color: AppColors.primaryColor(context), size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        HapticUtils.light();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NoticeBoardScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      HapticUtils.light();
                      final shellState = context.findAncestorStateOfType<AppShellState>();
                      if (shellState != null) {
                        shellState.switchTab(3); // 3 = More tab
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : AppColors.softGold(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.primaryColor(context).withValues(alpha: 0.4) : b.themeColor.withValues(alpha: 0.3)),
                        boxShadow: Theme.of(context).brightness == Brightness.dark
                            ? [BoxShadow(color: AppColors.primaryColor(context).withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 1)]
                            : null,
                        image: (b.logoUrl != null && b.logoUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(b.logoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: (b.logoUrl == null || b.logoUrl!.isEmpty)
                          ? Text(
                              (b.companyName.isNotEmpty
                                      ? b.companyName
                                      : _contractorName)
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness == Brightness.dark ? AppColors.primaryColor(context) : b.themeColorLight,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodaySummary(DashboardProvider dash, SiteDataProvider data,
      int sitesCount, int pendingSitesCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatChip(
                  label: 'Present',
                  value: dash.presentToday.toString(),
                  color: AppColors.successColor(context),
                  bgColor: const Color(0xFF102D2D),
                  icon: Icons.groups_rounded),
              const SizedBox(width: 8),
              StatChip(
                  label: 'Half Day',
                  value: dash.halfToday.toString(),
                  color: AppColors.warningColor(context),
                  bgColor: const Color(0xFF2A2517),
                  icon: Icons.person_rounded),
              const SizedBox(width: 8),
              StatChip(
                  label: 'Absent',
                  value: dash.absentToday.toString(),
                  color: AppColors.errorColor(context),
                  bgColor: const Color(0xFF2B1823),
                  icon: Icons.person_off_rounded),
            ],
          ),
          const SizedBox(height: 16),
          GlassCard(
            useBlur: false,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today\'s Labour Cost',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF91A7BE) : AppColors.textSecondaryColor(context),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: data.todayWageTotal),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOut,
                        builder: (ctx, val, _) => Text(
                          '₹${val.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryColor(context)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0x1F91AAC8) : AppColors.subtleBorderColor(context),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sites Today',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF91A7BE) : AppColors.textSecondaryColor(context),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('$sitesCount',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF4F7FB) : AppColors.textPrimaryColor(context))),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0x1F91AAC8) : AppColors.subtleBorderColor(context),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF91A7BE) : AppColors.textSecondaryColor(context),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('$pendingSitesCount',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: pendingSitesCount > 0
                                ? AppColors.warningColor(context)
                                : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF4F7FB) : AppColors.textPrimaryColor(context)),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions(List<SiteModel> sites, int pendingSitesCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ActionTile(
            icon: Icons.qr_code_scanner_rounded,
            label: 'QR Attendance',
            subtitle: 'Scan labour cards',
            color: AppColors.qrTint,
            bgColor: const Color(0xFF102B2B),
            iconBgColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0D3A37) : null,
            onTap: () async {
              HapticUtils.light();
              if (sites.isEmpty) {
                AppSnackBar.showError(context, 'No active sites available.');
                return;
              }
              if (sites.length == 1) {
                final session = _todaySessions
                    .cast<AttendanceSession?>()
                    .firstWhere((s) => s!.siteId == sites.first.id,
                        orElse: () => null);
                _onSiteTap(sites.first, session);
              } else {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppColors.cardColor(context),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Select Site to Scan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: sites.length,
                              itemBuilder: (ctx, i) {
                                final site = sites[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppColors.primaryColor(context)
                                            .withValues(alpha: 0.1),
                                    child: Icon(Icons.location_on_rounded,
                                        color: AppColors.primaryColor(context)),
                                  ),
                                  title: Text(
                                    site.name,
                                    style: TextStyle(
                                      color:
                                          AppColors.textPrimaryColor(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    final session = _todaySessions
                                        .cast<AttendanceSession?>()
                                        .firstWhere((s) => s!.siteId == site.id,
                                            orElse: () => null);
                                    _onSiteTap(site, session);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 12),
          ActionTile(
            icon: Icons.pan_tool_rounded,
            label: 'Manual',
            subtitle: 'Mark attendance',
            color: AppColors.manualTint,
            bgColor: const Color(0xFF12243A),
            iconBgColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF102F58) : null,
            onTap: () {
              HapticUtils.light();
              final shellState =
                  context.findAncestorStateOfType<AppShellState>();
              if (shellState != null) {
                shellState.switchToTab(1); // 1 = Attendance
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModuleGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ModuleCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  subtitle: 'Insights & data',
                  color: AppColors.reportsTint,
                  bgColor: const Color(0xFF16132D),
                  iconBgColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF231B45) : null,
                  onTap: () {
                    HapticUtils.light();
                    final shellState =
                        context.findAncestorStateOfType<AppShellState>();
                    if (shellState != null) {
                      shellState.switchToTab(2); // 2 = Reports
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModuleCard(
                  icon: Icons.assignment_turned_in_rounded,
                  label: 'Daily Closing',
                  subtitle: 'Close the day',
                  color: AppColors.closingTint,
                  bgColor: const Color(0xFF182221),
                  iconBgColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF153A35) : null,
                  onTap: () {
                    HapticUtils.light();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DailyClosingScreen()));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ModuleCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Materials',
                  subtitle: 'Site materials',
                  color: AppColors.materialsTint,
                  bgColor: const Color(0xFF291B1A),
                  iconBgColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF45201A) : null,
                  onTap: () {
                    HapticUtils.light();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SiteCostDashboardScreen()));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ModuleCard(
                  icon: Icons.calculate_rounded,
                  label: 'Calculator',
                  subtitle: 'Construction tools',
                  color: AppColors.calculatorTint,
                  bgColor: const Color(0xFF282316),
                  iconBgColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF453517) : null,
                  onTap: () {
                    HapticUtils.light();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CalculatorScreen()));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ModuleCard(
              icon: Icons.location_on_rounded,
              label: 'Sites',
              subtitle: 'Manage attendance',
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFFF4F7FB) : const Color(0xFF4A6583),
              bgColor: AppColors.surfaceSecondaryColor(context),
              iconBgColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF13243A) : null,
              onTap: () {
                HapticUtils.light();
                final shellState =
                    context.findAncestorStateOfType<AppShellState>();
                if (shellState != null) {
                  shellState.switchToTab(1); // 1 = Attendance
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSitesList(List<SiteModel> sites) {
    if (sites.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Today\'s Sites',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF4F7FB) : AppColors.textPrimaryColor(context))),
              const Spacer(),
              Text('${sites.length}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF4F7FB) : AppColors.textPrimaryColor(context))),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<AttendanceProvider>(
            builder: (context, attendanceProvider, _) {
              return Column(
                children: sites.take(3).map((site) {
                  final hasAttendance = (attendanceProvider.siteMap[site.id]?.isNotEmpty == true);
                  final session = _todaySessions
                      .cast<AttendanceSession?>()
                      .firstWhere((s) => s!.siteId == site.id,
                          orElse: () => null);
                  
                  String status = 'Pending';
                  if (hasAttendance) {
                    status = 'Completed';
                  } else if (session != null && session.status == SessionStatus.active) {
                    status = 'In Progress';
                  }

                  int labourCount = 0;
                  for (final summary
                      in attendanceProvider.dailyShiftMap.values) {
                    final thisSiteVisit = summary.siteVisits
                        .where((v) => v.siteId == site.id)
                        .firstOrNull;
                    if (thisSiteVisit != null && thisSiteVisit.factor > 0) {
                      labourCount++;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SiteRow(
                      name: site.name,
                      labourCount: labourCount,
                      status: status,
                      onTap: () {
                        HapticUtils.light();
                        final shellState =
                            context.findAncestorStateOfType<AppShellState>();
                        if (shellState != null) {
                          shellState.switchToTab(1); // 1 = Attendance
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (sites.length > 3)
            Center(
              child: TextButton(
                onPressed: () {
                  final shellState =
                      context.findAncestorStateOfType<AppShellState>();
                  if (shellState != null) {
                    shellState.switchToTab(1); // 1 = Attendance
                  }
                },
                child: Text('View all sites',
                    style:
                        TextStyle(color: AppColors.textTertiaryColor(context))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNeedsAttention(int pendingSitesCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Needs Attention',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryColor(context))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pendingSitesCount > 0)
                  AttentionItem(
                    icon: Icons.warning_rounded,
                    message:
                        'Attendance pending at $pendingSitesCount site${pendingSitesCount == 1 ? '' : 's'}',
                  ),
                if (pendingSitesCount == 0)
                  const AttentionItem(
                    icon: Icons.check_circle_rounded,
                    message: 'Everything looks good today!',
                    isWarning: false,
                  ),
                if (pendingSitesCount == 0)
                  const AttentionItem(
                    icon: Icons.task_alt_rounded,
                    message: 'Daily closing available',
                    isWarning: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
