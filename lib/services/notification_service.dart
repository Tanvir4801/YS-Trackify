import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  NotificationService._();
  static NotificationService get instance => _instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      debugPrint('[NotificationService] Web platform — push notifications skipped.');
      return;
    }

    try {
      await _initMobile();
    } catch (e) {
      debugPrint('[NotificationService] init error: $e');
    }
  }

  Future<void> _initMobile() async {
    debugPrint('[NotificationService] Mobile init skipped (plugin not directly imported).');
  }

  Future<void> showAttendanceSyncSuccess(int count) async {
    if (kIsWeb || count == 0) return;
    debugPrint('[NotificationService] Sync success: $count records');
  }

  Future<void> showOfflineScanQueued(String labourName) async {
    if (kIsWeb) return;
    debugPrint('[NotificationService] Offline scan queued for $labourName');
  }
}
