import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/haptic_utils.dart';
import '../providers/site_data_provider.dart';
import '../services/auth_service.dart';
import '../services/scanner_service.dart';
import '../services/session_service.dart';
import '../widgets/offline_banner.dart';
import '../widgets/bridge_bottom_nav_bar.dart';

import '../core/localization/app_text.dart';
import '../main.dart';

import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'reports_screen.dart';
import 'cost_management/site_cost_dashboard_screen.dart';
import 'calculator/calculator_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription? _connectivitySub;
  final _scannerService = ScannerService();

  final List<Widget> _screens = const [
    DashboardScreen(),
    AttendanceScreen(),
    ReportsScreen(),
    SiteCostDashboardScreen(),
    CalculatorScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLabourStream();
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && mounted) {
        _startLabourStream();
        _syncPending();
      }
    });
  }

  void _startLabourStream() {
    final contractorId = SessionService.instance.contractorId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    if (contractorId.isNotEmpty && mounted) {
      context.read<SiteDataProvider>().startLabourStream(contractorId);
    }
  }

  Future<void> _syncPending() async {
    try {
      final count = await _scannerService.syncPendingScans();
      if (count > 0) {
        debugPrint('[AppShell] Auto-synced $count pending attendance records');
      }
    } catch (e) {
      debugPrint('[AppShell] Auto-sync error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _startLabourStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    context.read<SiteDataProvider>().stopLabourStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      extendBody: true,
      body: OfflineBanner(
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: BridgeBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          HapticUtils.light();
          setState(() => _currentIndex = i);
        },
        labels: [
          context.tr('dashboard'),
          context.tr('attendance'),
          context.tr('reports'),
          'Costs',
          'Toolkit',
        ],
        icons: const [
          Icons.grid_view_rounded,
          Icons.fact_check_outlined,
          Icons.bar_chart_outlined,
          Icons.account_balance_wallet_outlined,
          Icons.handyman_outlined,
        ],
        activeIcons: const [
          Icons.grid_view_rounded,
          Icons.fact_check_rounded,
          Icons.bar_chart_rounded,
          Icons.account_balance_wallet_rounded,
          Icons.handyman_rounded,
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    HapticUtils.light();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ctx.tr('logout')),
          content: Text(ctx.tr('logoutConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('cancel'),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.absent),
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
}
