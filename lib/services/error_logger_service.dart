import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'support_ticket_service.dart';

/// Global Error Logger Service for Flutter
/// Catches UI, framework, and business logic errors and logs them to Firestore.
class ErrorLoggerService {
  ErrorLoggerService._();

  static final ErrorLoggerService instance = ErrorLoggerService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Setup global error handlers. Call this in main() before runApp().
  Future<void> initialize() async {
    // Catch Flutter UI errors
    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.presentError(details);
      await logError(
        error: details.exception,
        stackTrace: details.stack,
        type: 'Flutter Error',
        module: 'UI Framework',
        severity: 'HIGH',
      );
    };

    // Catch asynchronous Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      logError(
        error: error,
        stackTrace: stack,
        type: 'Dart Error',
        module: 'Platform Dispatcher',
        severity: 'CRITICAL',
      );
      return true; // Prevents crash in release mode
    };
  }

  /// Manually log an error from a try/catch block
  Future<void> logError({
    required dynamic error,
    StackTrace? stackTrace,
    String type = 'App Error',
    String module = 'General',
    String severity = 'MEDIUM', // LOW, MEDIUM, HIGH, CRITICAL
    String? userId,
    String? companyId,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      
      final errorPayload = {
        'message': error.toString(),
        'stackTrace': stackTrace?.toString(),
        'type': type,
        'module': module,
        'severity': severity,
        'status': 'NEW', // NEW, INVESTIGATING, IN_PROGRESS, FIXED, RESOLVED, IGNORED
        'userId': userId,
        'companyId': companyId,
        'deviceInfo': deviceInfo,
        'additionalData': additionalData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'history': [
          {
            'status': 'NEW',
            'timestamp': DateTime.now().toIso8601String(),
            'updatedBy': 'system',
            'note': 'Error logged automatically by mobile app'
          }
        ]
      };

      await _db.collection('error_logs').add(errorPayload);
      
      // Auto-create a support ticket for CRITICAL errors
      if (severity == 'CRITICAL') {
        try {
          // Fire and forget, but catch async errors to prevent infinite loops with PlatformDispatcher
          SupportTicketService.instance.createTicket(
            type: 'App Crash',
            issue: 'Auto-generated crash report: ${error.toString().split('\n').first}',
            priority: 'Critical',
          ).catchError((ticketError) {
            debugPrint('Failed to auto-create support ticket for crash (async): $ticketError');
          });
        } catch (ticketError) {
          debugPrint('Failed to auto-create support ticket for crash (sync): $ticketError');
        }
      }

      debugPrint('Error successfully logged to Firestore: $error');
    } catch (e) {
      // Failsafe: if logging to Firestore fails, print to console
      debugPrint('FAILED TO LOG ERROR TO FIRESTORE: $e');
      debugPrint('Original Error: $error');
    }
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final Map<String, String> data = {};
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      data['appVersion'] = packageInfo.version;
      data['buildNumber'] = packageInfo.buildNumber;

      if (kIsWeb) {
        data['platform'] = 'Web';
      } else {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          data['platform'] = 'Android';
          data['osVersion'] = androidInfo.version.release;
          data['device'] = '${androidInfo.brand} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          data['platform'] = 'iOS';
          data['osVersion'] = iosInfo.systemVersion;
          data['device'] = iosInfo.utsname.machine;
        } else {
          data['platform'] = Platform.operatingSystem;
        }
      }
    } catch (e) {
      data['platform'] = 'Unknown';
    }
    return data;
  }
}
