import 'package:flutter/material.dart';
import '../services/auth_service.dart';

import '../core/localization/app_text.dart';
import '../main.dart';

import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'labour_screen.dart';
import 'reports_screen.dart';
import 'scanner/scanner_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    LabourScreen(),
    AttendanceScreen(),
    ReportsScreen(),
    ScannerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('supervisorDashboard'),
      context.tr('labourManagement'),
      context.tr('attendance'),
      context.tr('reports'),
      'Scan Attendance',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            tooltip: context.tr('logout'),
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.construction_outlined),
            label: context.tr('dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.badge_outlined),
            label: context.tr('labour'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fact_check_outlined),
            label: context.tr('attendance'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            label: context.tr('reports'),
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            label: 'Scanner',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(ctx.tr('logout')),
          content: Text(ctx.tr('logoutConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);

    await AuthService().logout();

    if (!mounted) {
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }
}
