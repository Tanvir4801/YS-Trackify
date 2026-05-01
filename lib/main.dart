import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart' as legacy_provider;

import 'firebase_options.dart';
import 'models/attendance_model.dart';
import 'models/labour_model.dart';
import 'models/payment_model.dart';
import 'providers/attendance_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/labour_provider.dart';
import 'providers/language_provider.dart';
import 'providers/report_provider.dart';
import 'providers/site_data_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/app_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/labour_home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/unauthorized_screen.dart';
import 'services/hive_service.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String supervisorHome = '/supervisor-home';
  static const String labourHome = '/labour-home';
  static const String unauthorized = '/unauthorized';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // For local emulator testing only — remove for production.
  // FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(20)) {
    Hive.registerAdapter(LabourAdapter());
  }
  if (!Hive.isAdapterRegistered(21)) {
    Hive.registerAdapter(AttendanceStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(22)) {
    Hive.registerAdapter(AttendanceAdapter());
  }
  if (!Hive.isAdapterRegistered(23)) {
    Hive.registerAdapter(PaymentTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(24)) {
    Hive.registerAdapter(PaymentAdapter());
  }

  await Hive.openBox<Labour>(Labour.boxName);
  await Hive.openBox<Attendance>(Attendance.boxName);
  await Hive.openBox<Payment>(Payment.boxName);
  await Hive.openBox('pending_attendance');

  final hiveService = HiveService();
  await hiveService.init();

  final languageProvider = LanguageProvider();
  await languageProvider.initialize();

  runApp(
    legacy_provider.MultiProvider(
      providers: [
        legacy_provider.ChangeNotifierProvider<LanguageProvider>.value(
          value: languageProvider,
        ),
        legacy_provider.ChangeNotifierProvider<SiteDataProvider>(
          create: (_) => SiteDataProvider(hiveService: hiveService),
        ),
        legacy_provider.ChangeNotifierProvider<AttendanceProvider>(
          create: (_) => AttendanceProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<LabourProvider>(
          create: (_) => LabourProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<ReportProvider>(
          create: (_) => ReportProvider(),
        ),
      ],
      child: const ProviderScope(child: TrackifyApp()),
    ),
  );
}

class TrackifyApp extends ConsumerStatefulWidget {
  const TrackifyApp({super.key});

  @override
  ConsumerState<TrackifyApp> createState() => _TrackifyAppState();
}

class _TrackifyAppState extends ConsumerState<TrackifyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncEngineProvider).startConnectivityListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trackify V2',
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.supervisorHome: (_) => const AppShell(),
        AppRoutes.labourHome: (_) => const LabourHomeScreen(),
        AppRoutes.unauthorized: (_) => const UnauthorizedScreen(),
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
      ),
    );
  }
}
