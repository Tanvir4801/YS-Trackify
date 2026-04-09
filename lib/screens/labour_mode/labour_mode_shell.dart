import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_text.dart';
import '../../main.dart';
import '../../models/labour.dart';
import '../../services/auth/labour_auth_service.dart';
import '../../services/hive_service.dart';
import '../../services/labour_mode/labour_service.dart';
import 'labour_attendance_screen.dart';
import 'labour_dashboard_screen.dart';
import 'payment_history_screen.dart';

class LabourModeShell extends StatefulWidget {
  const LabourModeShell({
    super.key,
    required this.labour,
    required this.hiveService,
  });

  final Labour labour;
  final HiveService hiveService;

  @override
  State<LabourModeShell> createState() => _LabourModeShellState();
}

class _LabourModeShellState extends State<LabourModeShell> {
  int _currentIndex = 0;
  late final LabourService _labourService;
  static const String _supervisorPhone = '+917621984915';

  @override
  void initState() {
    super.initState();
    _labourService = LabourService(hiveService: widget.hiveService);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      LabourDashboardScreen(labour: widget.labour, labourService: _labourService),
      LabourAttendanceScreen(labour: widget.labour, labourService: _labourService),
      PaymentHistoryScreen(labour: widget.labour, hiveService: widget.hiveService),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('labourMode')} - ${widget.labour.name}'),
        actions: [
          IconButton(
            tooltip: context.tr('callSupervisor'),
            onPressed: _callSupervisor,
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: context.tr('logout'),
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            label: context.tr('dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.fact_check_outlined),
            label: context.tr('attendance'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            label: 'Payments',
          ),
        ],
        onTap: (index) {
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

    final labourAuthService = LabourAuthService(hiveService: widget.hiveService);
    await labourAuthService.clearSession();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.modeSelection,
      (route) => false,
    );
  }

  Future<void> _callSupervisor() async {
    final phone = _supervisorPhone.trim();
    if (phone.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('supervisorUnavailable'))));
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('supervisorUnavailable'))));
    }
  }
}
