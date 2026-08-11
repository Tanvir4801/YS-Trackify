import 'dart:async';
import 'dart:io' show Platform, HttpClient;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service that routinely pings the TrackOps 'live_users' collection to report
/// app health, current screen, and network latency.
class HealthPingService {
  HealthPingService._();
  static final HealthPingService instance = HealthPingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _pingTimer;
  StreamSubscription? _monitoringSub;
  bool _isMonitoringEnabled = false;
  
  String? _currentUserId;
  String? _currentCompanyId;
  String? _companyName;
  String? _userName;
  String? _role;
  String? _subscriptionPlan;
  DateTime? _loginTime;
  String _currentScreen = 'Background/Unknown';
  int _crashCount = 0;
  
  // Cached device info
  Map<String, String>? _deviceInfoCache;

  /// Call this when a user logs in or the app enters foreground
  void startPinging({
    required String userId, 
    required String companyId,
    String? companyName,
    String? userName,
    String? role,
    String? subscriptionPlan,
  }) {
    _currentUserId = userId;
    _currentCompanyId = companyId;
    _companyName = companyName;
    _userName = userName;
    _role = role;
    _subscriptionPlan = subscriptionPlan;
    _loginTime ??= DateTime.now();
    
    // Listen to global monitoring state
    _monitoringSub?.cancel();
    _monitoringSub = _db.collection('trackops_config').doc('monitoring').snapshots().listen((snap) {
      if (snap.exists) {
        _isMonitoringEnabled = snap.data()?['enabled'] == true;
      }
    });

    // Ping immediately on start
    if (_isMonitoringEnabled) _sendPing();

    // Setup periodic ping every 60 seconds
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_isMonitoringEnabled) _sendPing();
    });
  }

  /// Update the current screen the user is viewing
  void updateScreen(String screenName) {
    _currentScreen = screenName;
  }

  /// Stop pinging when user logs out or app goes to background
  void stopPinging() {
    _monitoringSub?.cancel();
    _monitoringSub = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _loginTime = null;
    _crashCount = 0;
  }

  /// Increment crash count
  void incrementCrashCount() {
    _crashCount++;
  }

  Future<void> _sendPing() async {
    if (_currentUserId == null) return;

    try {
      final deviceInfo = await _getDeviceInfo();
      final latencyMs = await _measureLatency();

      final pingPayload = {
        'userId': _currentUserId,
        'companyId': _currentCompanyId ?? 'Unknown',
        'companyName': _companyName ?? 'Unknown',
        'userName': _userName ?? 'Unknown',
        'role': _role ?? 'contractor',
        'subscriptionPlan': _subscriptionPlan ?? 'Free',
        'appVersion': deviceInfo['appVersion'] ?? 'Unknown',
        'platform': deviceInfo['platform'] ?? 'Unknown',
        'deviceModel': deviceInfo['deviceModel'] ?? 'Unknown',
        'networkStatus': latencyMs == -1 ? 'OFFLINE' : (latencyMs > 1000 ? 'SLOW' : 'ONLINE'),
        'currentScreen': _currentScreen,
        'latencyMs': latencyMs,
        'loginTime': _loginTime?.toIso8601String(),
        'sessionDurationMins': _loginTime != null ? DateTime.now().difference(_loginTime!).inMinutes : 0,
        'crashCount': _crashCount,
        'firebaseConnectionStatus': latencyMs == -1 ? 'DISCONNECTED' : 'CONNECTED',
        'lastSeen': FieldValue.serverTimestamp(),
      };

      // Upsert into live_users collection
      // Document ID is the userId so we don't create infinite docs per user
      await _db.collection('live_users').doc(_currentUserId).set(pingPayload, SetOptions(merge: true));

    } catch (e) {
      debugPrint('Failed to send health ping: $e');
    }
  }

  /// Measures approximate network latency by hitting Google DNS or equivalent
  Future<int> _measureLatency() async {
    if (kIsWeb) return 50; // Stub for web
    final stopwatch = Stopwatch()..start();
    try {
      // In production, pinging a robust endpoint or your own Firebase function is better.
      // Using google.com as a simple connectivity check.
      final request = await HttpClient().head('google.com', 80, '/').timeout(const Duration(seconds: 3));
      final response = await request.close();
      if (response.statusCode == 200) {
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {}
    return -1; // -1 denotes offline/timeout
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    if (_deviceInfoCache != null) return _deviceInfoCache!;

    final Map<String, String> data = {};
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      data['appVersion'] = '${packageInfo.version}+${packageInfo.buildNumber}';

      if (kIsWeb) {
        data['platform'] = 'Web';
      } else {
        final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          data['platform'] = 'Android';
          data['deviceModel'] = androidInfo.model;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          data['platform'] = 'iOS';
          data['deviceModel'] = iosInfo.utsname.machine;
        } else {
          data['platform'] = Platform.operatingSystem;
          data['deviceModel'] = 'Desktop';
        }
      }
    } catch (e) {
      data['platform'] = 'Unknown';
    }
    
    _deviceInfoCache = data;
    return data;
  }
}
