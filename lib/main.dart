import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart' as legacy_provider;

import 'firebase_options.dart';
import 'debug/firestore_audit.dart';
import 'models/attendance_model.dart';
import 'models/labour_model.dart';
import 'models/payment_model.dart';
import 'models/site_model.dart';
import 'models/material_purchase_model.dart';
import 'models/supplier_model.dart';
import 'models/site_expense_model.dart';
import 'models/daily_closing_report.dart';
import 'providers/attendance_provider.dart';
import 'services/temp_labour_cleanup_service.dart';
import 'providers/dashboard_provider.dart';
import 'providers/labour_provider.dart';
import 'providers/language_provider.dart';
import 'providers/report_provider.dart';
import 'providers/site_data_provider.dart';
import 'providers/sites_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/cost_management_provider.dart';
import 'providers/closing_report_provider.dart';
import 'providers/super_admin_provider.dart';
import 'providers/toolkit_provider.dart';
import 'providers/branding_provider.dart';
import 'screens/app_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/super_admin/super_admin_dashboard_screen.dart';
import 'screens/labour_mode/labour_mode_shell.dart';
import 'screens/settings/app_info_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/unauthorized_screen.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'widgets/offline_banner.dart';
import 'core/observers/telemetry_route_observer.dart';
import 'dart:async';
import 'services/auth_service.dart';
import 'services/security_service.dart';
import 'services/performance_service.dart';
import 'services/error_logger_service.dart';
import 'package:flutter/foundation.dart';

final DateTime appStartTime = DateTime.now();
final telemetryRouteObserver = TelemetryRouteObserver();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String supervisorHome = '/supervisor-home';
  static const String labourHome = '/labour-home';
  static const String superAdmin = '/super-admin';
  static const String unauthorized = '/unauthorized';
  static const String appInfo = '/app-info';
}


Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ErrorLoggerService.instance.initialize();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      ErrorLoggerService.instance.logError(
        error: details.exceptionAsString(),
        stackTrace: details.stack,
      );
    };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      ErrorLoggerService.instance.logError(error: 'Startup failure', stackTrace: StackTrace.fromString(e.toString()));
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  const Text('Trackify could not connect to the service.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {}, 
                    child: const Text('Please check your internet and restart the app.'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }
  }

  // Temporary audit — run in a fire-and-forget way (never blocks startup).
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      // ignore: unawaited_futures
      FirestoreAudit.runAudit();
      TempLabourCleanupService.runCleanup();
    }
  });

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

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
  if (!Hive.isAdapterRegistered(30)) {
    Hive.registerAdapter(SiteModelAdapter());
  }
  if (!Hive.isAdapterRegistered(31)) {
    Hive.registerAdapter(MaterialPurchaseModelAdapter());
  }
  if (!Hive.isAdapterRegistered(32)) {
    Hive.registerAdapter(SupplierModelAdapter());
  }
  if (!Hive.isAdapterRegistered(33)) {
    Hive.registerAdapter(SiteExpenseModelAdapter());
  }
  if (!Hive.isAdapterRegistered(34)) {
    Hive.registerAdapter(DailyClosingReportAdapter());
  }

  await Hive.openBox<Labour>(Labour.boxName);
  await Attendance.openBoxSafely();
  await Hive.openBox<Payment>(Payment.boxName);
  await Hive.openBox('pending_attendance');
  await Hive.openBox<SiteModel>(SiteModel.boxName);
  await Hive.openBox<MaterialPurchaseModel>(MaterialPurchaseModel.boxName);
  await Hive.openBox<SupplierModel>(SupplierModel.boxName);
  await Hive.openBox<SiteExpenseModel>(SiteExpenseModel.boxName);
  await Hive.openBox<DailyClosingReport>(DailyClosingReport.boxName);

  final hiveService = HiveService();
  await hiveService.init();

  final languageProvider = LanguageProvider();
  await languageProvider.initialize();

  await NotificationService.instance.initialize();

  runApp(
    legacy_provider.MultiProvider(
      providers: [
        legacy_provider.ChangeNotifierProvider<LanguageProvider>.value(
          value: languageProvider,
        ),
        legacy_provider.ChangeNotifierProvider<SiteDataProvider>(
          create: (_) => SiteDataProvider(hiveService: hiveService)..initialize(),
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
        legacy_provider.ChangeNotifierProvider<ReportsProvider>(
          create: (_) => ReportsProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<SitesProvider>(
          create: (_) => SitesProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<CostManagementProvider>(
          create: (_) => CostManagementProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<ClosingReportProvider>(
          create: (_) => ClosingReportProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<SuperAdminProvider>(
          create: (_) => SuperAdminProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<ToolkitProvider>(
          create: (_) => ToolkitProvider(),
        ),
        legacy_provider.ChangeNotifierProvider<BrandingProvider>(
          create: (_) => BrandingProvider(),
        ),
      ],
      child: const ProviderScope(child: TrackifyApp()),
    ),
  );
  }, (error, stackTrace) {
    debugPrint('Global unhandled error: $error');
    ErrorLoggerService.instance.logError(error: error.toString(), stackTrace: StackTrace.fromString(stackTrace.toString()));
  });
}

class TrackifyApp extends ConsumerStatefulWidget {
  const TrackifyApp({super.key});

  @override
  ConsumerState<TrackifyApp> createState() => _TrackifyAppState();
}

class _TrackifyAppState extends ConsumerState<TrackifyApp>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  StreamSubscription<QuerySnapshot>? _broadcastSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Record startup time once the first frame renders
      final startupDuration = DateTime.now().difference(appStartTime).inMilliseconds;
      PerformanceService.instance.logDuration('Startup Time', startupDuration);

      ref.read(syncEngineProvider).startConnectivityListener();
      _listenForBroadcasts();
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userDocSub?.cancel();
      if (user != null) {
        _userDocSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snap) async {
          if (snap.exists) {
            final data = snap.data()!;
            final isActive = data['isActive'] as bool? ?? true;
            final forceReason = data['forceLogoutReason'] as String?;
            
            if (!isActive || forceReason != null) {
              if (forceReason != null) {
                try {
                  // Must delete this BEFORE signing out, otherwise Firestore rules block it!
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'forceLogoutReason': FieldValue.delete(),
                  });
                } catch (_) {}
              }
              
              await AuthService().logout();
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
            }
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SecurityService.instance.pingSession();
    }
  }

  void _listenForBroadcasts() {
    final now = DateTime.now();
    _broadcastSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('active', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final timestamp = data['timestamp'] as Timestamp?;
        // Only show if the broadcast was sent AFTER the app started
        if (timestamp != null && timestamp.toDate().isAfter(now)) {
          final title = data['title'] ?? 'System Broadcast';
          final body = data['body'] ?? '';
          
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              SnackBar(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                elevation: 0,
                duration: const Duration(seconds: 12),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                content: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2438),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00FF66).withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF66).withOpacity(0.15),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 4,
                          child: Container(color: const Color(0xFF00FF66)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF66).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.campaign_rounded, color: Color(0xFF00FF66), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF00FF66),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      body,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => ScaffoldMessenger.of(navigatorKey.currentContext!).hideCurrentSnackBar(),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.close, color: Colors.white54, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    _broadcastSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return legacy_provider.Consumer<BrandingProvider>(
      builder: (context, brand, child) {
        final color = brand.branding.themeColor;
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Trackify V2',
          builder: (context, child) {
            return OfflineBanner(child: child!);
          },
          navigatorObservers: [telemetryRouteObserver],
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.supervisorHome: (_) => const AppShell(),
            AppRoutes.labourHome: (_) => const LabourModeShell(),
            AppRoutes.superAdmin: (_) => const SuperAdminDashboardScreen(),
            AppRoutes.unauthorized: (_) => const UnauthorizedScreen(),
            AppRoutes.appInfo: (_) => const AppInfoScreen(),
          },
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF10141C),
            colorScheme: ColorScheme.dark(
              primary: color,
              surface: const Color(0xFF1A2438),
            ),
            useMaterial3: true,
          ),
        );
      },
    );
  }
}
