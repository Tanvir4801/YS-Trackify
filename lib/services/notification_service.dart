import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
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
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[NotificationService] Notification tapped: ${response.payload}');
      },
    );

    // Request permissions on Android 13+ (API 33+)
    final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatform != null) {
      await androidPlatform.requestNotificationsPermission();
    }
  }

  /// Sends a direct Engineer Reminder alert for pending house plans & visits
  Future<void> showPendingPlansReminder({
    required int pendingPlansCount,
    required int pendingDrawingsCount,
    required int visitDueCount,
  }) async {
    if (kIsWeb) return;
    if (pendingPlansCount == 0 && pendingDrawingsCount == 0 && visitDueCount == 0) return;

    final List<String> detailsList = [];
    if (pendingPlansCount > 0) detailsList.add('$pendingPlansCount plan fee pending');
    if (pendingDrawingsCount > 0) detailsList.add('$pendingDrawingsCount drawings in progress');
    if (visitDueCount > 0) detailsList.add('$visitDueCount visits due');

    final summary = detailsList.join(' • ');

    const androidDetails = AndroidNotificationDetails(
      'pending_plans_reminder',
      'House Plans Reminders',
      channelDescription: 'Alerts and reminders for pending house plans and site visits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      showWhen: true,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        201, // Unique ID for plans reminder
        '👷‍♂️ Engineer Alert: Pending Plans Notice',
        'Review needed: $summary. Tap to manage.',
        details,
      );
    } catch (e) {
      debugPrint('[NotificationService] Failed to show notification: $e');
    }
  }

  /// Rate-limited checker: triggers notification at most once every 6 hours, or immediately if force is true
  Future<void> checkAndTriggerPlansReminder({
    required int pendingPlansCount,
    required int pendingDrawingsCount,
    required int visitDueCount,
    bool force = false,
  }) async {
    if (kIsWeb) return;
    if (pendingPlansCount == 0 && pendingDrawingsCount == 0 && visitDueCount == 0) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('last_plans_reminder_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Send at most once every 6 hours unless force is true (manual button press)
      const sixHours = 6 * 60 * 60 * 1000;
      if (force || (now - lastTime > sixHours)) {
        await showPendingPlansReminder(
          pendingPlansCount: pendingPlansCount,
          pendingDrawingsCount: pendingDrawingsCount,
          visitDueCount: visitDueCount,
        );
        await prefs.setInt('last_plans_reminder_timestamp', now);
      }
    } catch (e) {
      debugPrint('[NotificationService] checkAndTriggerPlansReminder error: $e');
    }
  }

  Future<void> showAttendanceSyncSuccess(int count) async {
    if (kIsWeb || count == 0) return;
    debugPrint('[NotificationService] Sync success: $count records');
  }

  Future<void> showOfflineScanQueued(String labourName) async {
    if (kIsWeb) return;
    debugPrint('[NotificationService] Offline scan queued for $labourName');
  }

  Future<void> scheduleDailyReportReminder() async {
    debugPrint('[NotificationService] Scheduled daily report reminder.');
  }

  Future<void> cancelDailyReportReminder() async {
    debugPrint('[NotificationService] Canceled daily report reminder.');
  }
}
