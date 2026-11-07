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
import 'dart:ui';


import '../core/localization/app_text.dart';
import '../main.dart';

import 'attendance_screen.dart';
import 'home/home_screen.dart';
import 'reports_screen.dart';
import 'more/more_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription? _connectivitySub;
  final _scannerService = ScannerService();

  final List<Widget> _screens = [
    const HomeScreen(),
    const AttendanceScreen(),
    const ReportsScreen(),
    MoreScreen(),
  ];

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient(context),
            ),
          ),
          if (isDark) ...[
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF2A900).withValues(alpha: 0.15),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 300,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3182F6).withValues(alpha: 0.15),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
          ],
          Column(
            children: [
              if (SessionService.instance.current?.isDemo == true)
                SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppColors.gold.withValues(alpha: 0.18),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: AppColors.gold),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'DEMO MODE · Read-Only (Trackify Demo)',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            SessionService.instance.clear();
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.login,
                              (route) => false,
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Exit', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF03070E).withValues(alpha: 0.8)
                  : const Color(0xFFFFFFFF).withValues(alpha: 0.65),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF91AAC8).withValues(alpha: 0.14) : const Color(0xFFDCE7F1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor(context),
                      );
                    }
                    return TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF8EA3B8) : AppColors.textSecondaryColor(context),
                    );
                  }),
                ),
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) {
                    HapticUtils.light();
                    setState(() => _currentIndex = i);
                  },
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: isDark 
                      ? const Color(0xFF332A13)
                      : AppColors.softGold(context),
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined, color: isDark ? const Color(0xFF718CA7) : const Color(0xFF6F8BA8)),
                      selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.primaryColor(context)),
                      label: context.tr('dashboard'),
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.fact_check_outlined, color: isDark ? const Color(0xFF718CA7) : const Color(0xFF6F8BA8)),
                      selectedIcon: Icon(Icons.fact_check_rounded, color: AppColors.primaryColor(context)),
                      label: context.tr('attendance'),
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_outlined, color: isDark ? const Color(0xFF718CA7) : const Color(0xFF6F8BA8)),
                      selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primaryColor(context)),
                      label: context.tr('reports'),
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.more_horiz_rounded, color: isDark ? const Color(0xFF718CA7) : const Color(0xFF6F8BA8)),
                      selectedIcon: Icon(Icons.more_horiz_rounded, color: AppColors.primaryColor(context)),
                      label: 'More',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                  style: TextStyle(color: AppColors.textSecondaryColor(context))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.errorColor(context)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
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

  void switchToTab(int index) {
    if (mounted && index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }
}
