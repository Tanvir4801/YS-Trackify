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

import '../core/localization/app_text.dart';
import '../main.dart';

import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'reports_screen.dart';
import 'settings/app_info_screen.dart';

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
      backgroundColor: AppColors.cream,
      extendBody: false,
      body: ConnectivityBanner(
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          HapticUtils.light();
          setState(() => _currentIndex = i);
        },
        labels: [
          context.tr('dashboard'),
          context.tr('attendance'),
          context.tr('reports'),
        ],
        onSettings: () {
          HapticUtils.light();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AppInfoScreen()),
          );
        },
        onLogout: _confirmLogout,
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

// ── Premium Dark-Pill Navigation Bar ──────────────────────────────────────────

class _PremiumNavBar extends StatelessWidget {
  const _PremiumNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.labels,
    required this.onSettings,
    required this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  static const _icons = [
    Icons.grid_view_rounded,
    Icons.fact_check_outlined,
    Icons.bar_chart_outlined,
  ];

  static const _activeIcons = [
    Icons.grid_view_rounded,
    Icons.fact_check_rounded,
    Icons.bar_chart_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              ...List.generate(
                3,
                (i) => _NavItem(
                  index: i,
                  currentIndex: currentIndex,
                  icon: _icons[i],
                  activeIcon: _activeIcons[i],
                  label: labels[i],
                  onTap: onTap,
                ),
              ),
              // Settings icon
              _IconAction(icon: Icons.info_outline_rounded, onTap: onSettings),
              // Logout icon
              _IconAction(icon: Icons.logout_outlined, onTap: onLogout),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  color: selected ? AppColors.gold : AppColors.textTertiary,
                  size: 21,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Colors.white : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Icon(icon, size: 20, color: AppColors.textTertiary),
      ),
    );
  }
}
