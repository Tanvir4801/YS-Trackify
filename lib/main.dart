import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';

import 'core/theme/app_theme.dart';
import 'providers/language_provider.dart';
import 'providers/site_data_provider.dart';
import 'screens/app_shell.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/labour_mode/labour_selection_screen.dart';
import 'screens/supervisor_pin_screen.dart';
import 'services/auth/supervisor_auth_service.dart';
import 'services/attendance_reminder_service.dart';
import 'services/hive_service.dart';

class AppRoutes {
  static const String splash = '/';
  static const String modeSelection = '/mode-selection';
  static const String supervisorPin = '/supervisor-pin';
  static const String supervisorShell = '/supervisor-shell';
  static const String labourSelection = '/labour-selection';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    return const Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  };

  final hiveService = HiveService();

  try {
    await hiveService.init().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Hive init failed: $e');
  }

  final languageProvider = LanguageProvider();
  try {
    await languageProvider.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Language init failed: $e');
  }

  final reminderService = AttendanceReminderService(hiveService: hiveService);

  runApp(
    YSTrackifyApp(
      hiveService: hiveService,
      languageProvider: languageProvider,
      reminderService: reminderService,
    ),
  );

  unawaited(_initializeBackgroundServices(
    hiveService: hiveService,
    reminderService: reminderService,
  ));
}

Future<void> _initializeBackgroundServices({
  required HiveService hiveService,
  required AttendanceReminderService reminderService,
}) async {
  try {
    tz.initializeTimeZones();
  } catch (e) {
    debugPrint('Timezone init failed: $e');
  }

  try {
    await reminderService.initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Reminder init failed: $e');
  }

  try {
    final authService = SupervisorAuthService();
    await authService.ensureDefaultPin().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Auth init failed: $e');
  }
}

class YSTrackifyApp extends StatelessWidget {
  const YSTrackifyApp({
    super.key,
    required this.hiveService,
    required this.languageProvider,
    required this.reminderService,
  });

  final HiveService hiveService;
  final LanguageProvider languageProvider;
  final AttendanceReminderService reminderService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider(
          create: (_) => SiteDataProvider(hiveService: hiveService),
        ),
      ],
      child: _StartupInitializer(
        reminderService: reminderService,
        child: Consumer<LanguageProvider>(
          builder: (context, language, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'YS Trackify',
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: ThemeMode.system,
              locale: language.locale,
              initialRoute: AppRoutes.splash,
              routes: {
                AppRoutes.splash: (_) => const SplashScreen(),
                AppRoutes.modeSelection: (_) => const ModeSelectionScreen(),
                AppRoutes.supervisorPin: (_) => const SupervisorPinScreen(),
                AppRoutes.supervisorShell: (_) => const AppShell(),
                AppRoutes.labourSelection: (_) => const LabourSelectionScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}

class _StartupInitializer extends StatefulWidget {
  const _StartupInitializer({
    required this.reminderService,
    required this.child,
  });

  final AttendanceReminderService reminderService;
  final Widget child;

  @override
  State<_StartupInitializer> createState() => _StartupInitializerState();
}

class _StartupInitializerState extends State<_StartupInitializer> {
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) {
      return;
    }
    _didInit = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final provider = context.read<SiteDataProvider>();
      await provider.initialize();
      await widget.reminderService.runDailyAttendanceCheck();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
