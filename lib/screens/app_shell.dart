import 'package:flutter/material.dart';

import '../core/localization/app_text.dart';
import '../main.dart';

import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'labour_screen.dart';
import 'reports_screen.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('supervisorDashboard'),
      context.tr('labourManagement'),
      context.tr('attendance'),
      context.tr('reports'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            tooltip: context.tr('logout'),
            onPressed: () => _confirmLogout(context),
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
        ],
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.tr('logout')),
          content: Text(context.tr('logoutConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.tr('logout')),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.modeSelection,
      (route) => false,
    );
  }
}
