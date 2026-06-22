import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'session_service.dart';

class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _sessionId;
  Map<String, String>? _deviceCache;

  String get sessionId {
    if (_sessionId == null) {
      _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}';
    }
    return _sessionId!;
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    if (_deviceCache != null) return _deviceCache!;
    
    final Map<String, String> data = {};
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      data['appVersion'] = packageInfo.version;

      if (kIsWeb) {
        data['platform'] = 'Web';
        data['deviceName'] = 'Web Browser';
      } else {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          data['platform'] = 'Android';
          data['deviceName'] = '${androidInfo.brand} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          data['platform'] = 'iOS';
          data['deviceName'] = iosInfo.utsname.machine;
        } else {
          data['platform'] = Platform.operatingSystem;
          data['deviceName'] = 'Unknown Device';
        }
      }
    } catch (e) {
      data['platform'] = 'Unknown';
      data['appVersion'] = 'Unknown';
      data['deviceName'] = 'Unknown';
    }
    
    _deviceCache = data;
    return data;
  }

  Future<void> logEvent({
    required String eventType, // e.g., 'screen_open', 'feature_usage', 'attendance_marked'
    String? featureName,
    String? screenName,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final companyId = SessionService.instance.contractorId ?? user.uid;
      
      // Fetch user role from users collection
      String role = 'unknown';
      try {
        final userDoc = await _db.collection('users').doc(user.uid).get(const GetOptions(source: Source.cache));
        if (userDoc.exists) {
          role = userDoc.data()?['role'] ?? 'unknown';
        } else {
          final netDoc = await _db.collection('users').doc(user.uid).get();
          role = netDoc.data()?['role'] ?? 'unknown';
        }
      } catch(_) {}

      final deviceInfo = await _getDeviceInfo();

      final payload = {
        'eventType': eventType,
        'featureName': featureName,
        'screenName': screenName,
        'userId': user.uid,
        'companyId': companyId,
        'role': role,
        'deviceName': deviceInfo['deviceName'],
        'appVersion': deviceInfo['appVersion'],
        'platform': deviceInfo['platform'],
        'timestamp': FieldValue.serverTimestamp(),
        'sessionId': sessionId,
      };

      if (additionalMetadata != null) {
        payload['additionalMetadata'] = additionalMetadata;
      }

      // Fire and forget
      _db.collection('telemetry_events').add(payload).catchError((_) {});
    } catch (e) {
      debugPrint('Telemetry Error: $e');
    }
  }

  void trackScreenOpen(String screenName) {
    logEvent(eventType: 'screen_open', screenName: screenName);
  }

  void trackFeatureUsage(String featureName, {Map<String, dynamic>? metadata, String? screenName}) {
    logEvent(
      eventType: 'feature_usage', 
      featureName: featureName, 
      screenName: screenName,
      additionalMetadata: metadata
    );
  }
}
