import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzInitialized = false;

  // Notification IDs
  static const int _idPlansReminder = 201;
  static const int _idMorningAttendance = 301;
  static const int _idMidDayCheck = 302;
  static const int _idPreDayEndAlert = 303;
  static const int _idFinalDayEndAlert = 304;
  static const int _idDailyClosingReport = 305;
  static const int _idLiveUnmarkedAlert = 306;
  static const int _idSyncSuccess = 310;
  static const int _idOfflineScan = 311;
  static const int _idTestNotification = 399;

  static const String _prefDailyRemindersEnabled =
      'supervisor_daily_reminders_enabled';
  static const String _prefLastUnmarkedAlertTs =
      'last_unmarked_attendance_alert_ts';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      debugPrint(
        '[NotificationService] Web platform — push notifications skipped.',
      );
      return;
    }

    try {
      _initTimezone();
      await _initMobile();

      // Automatically schedule daily attendance & day-end supervisor reminders
      // unless explicitly turned off in Settings.
      final enabled = await isDailyRemindersEnabled();
      if (enabled) {
        await scheduleSupervisorDailyReminders();
      }
    } catch (e) {
      debugPrint('[NotificationService] init error: $e');
    }
  }

  void _initTimezone() {
    if (_tzInitialized) return;
    _tzInitialized = true;
    tzdata.initializeTimeZones();
    try {
      // Match the device's local UTC offset cleanly (defaults to Asia/Kolkata for IST +5:30)
      final offset = DateTime.now().timeZoneOffset;
      if (offset == const Duration(hours: 5, minutes: 30)) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        return;
      }
      // Find first matching timezone location for current offset
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offset.inMilliseconds) {
          tz.setLocalLocation(loc);
          return;
        }
      }
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (e) {
      debugPrint('[NotificationService] timezone fallback: $e');
    }
  }

  Future<void> _initMobile() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint(
          '[NotificationService] Notification tapped: ${response.payload}',
        );
      },
    );

    // Request notification permissions on Android 13+ (API 33+)
    final androidPlatform = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlatform != null) {
      await androidPlatform.requestNotificationsPermission();
    }
  }

  // ── Preference Controls ────────────────────────────────────────────────────

  Future<bool> isDailyRemindersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefDailyRemindersEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setDailyRemindersEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDailyRemindersEnabled, enabled);
      if (enabled) {
        await scheduleSupervisorDailyReminders();
      } else {
        await cancelSupervisorDailyReminders();
      }
    } catch (e) {
      debugPrint('[NotificationService] setDailyRemindersEnabled error: $e');
    }
  }

  // ── Scheduled Automatic Daily Supervisor Reminders ─────────────────────────

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, {bool startTomorrow = false}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (startTomorrow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  NotificationDetails _attendanceChannelDetails({
    String channelId = 'supervisor_attendance_reminders',
    String channelName = 'Attendance & Day-End Reminders',
    String channelDescription =
        'Automatic daily labour attendance, advances, and day-end closing alerts for supervisors',
    Importance importance = Importance.high,
    Priority priority = Priority.high,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
        styleInformation: const BigTextStyleInformation(''),
      ),
    );
  }

  /// Schedules automatic daily supervisor notifications:
  /// - 9:30 AM: Start today's labour attendance
  /// - 2:00 PM: Mid-day shift & overtime check
  /// - 6:00 PM: Before day-end attendance, advances & closing alert
  /// - 7:30 PM: Final day-end wrap-up check before midnight
  Future<void> scheduleSupervisorDailyReminders({
    int? unmarkedCount,
    int? totalLabours,
  }) async {
    if (kIsWeb) return;
    _initTimezone();

    final enabled = await isDailyRemindersEnabled();
    if (!enabled) return;

    final details = _attendanceChannelDetails();

    final bool hasCounts = totalLabours != null && totalLabours > 0 && unmarkedCount != null;
    final bool allDoneToday = hasCounts && unmarkedCount == 0;

    final String eveningTitle = (hasCounts && unmarkedCount > 0)
        ? '⚠️ $unmarkedCount Labour${unmarkedCount == 1 ? '' : 's'} Still Unmarked Today!'
        : allDoneToday
            ? '✅ All $totalLabours Labours Marked — Save Closing Report'
            : '⚠️ Day-End Alert: Complete Today\'s Attendance';

    final String eveningBody = (hasCounts && unmarkedCount > 0)
        ? 'Before day end: mark attendance for the remaining $unmarkedCount of $totalLabours labours, check advances, and close today\'s register.'
        : allDoneToday
            ? 'Great work! All today\'s labour attendance is marked. Don\'t forget to record advances, site expenses, and save today\'s Daily Closing Report.'
            : 'Before day end: mark all remaining labour attendance, record cash advances, and save your Daily Closing Report.';

    final String finalTitle = (hasCounts && unmarkedCount > 0)
        ? '🔔 Final Reminder: $unmarkedCount Unmarked Labour${unmarkedCount == 1 ? '' : 's'}'
        : '🔔 Final Day-End Check — Trackify';

    final String finalBody = (hasCounts && unmarkedCount > 0)
        ? 'Day is ending soon! Complete attendance for $unmarkedCount remaining worker${unmarkedCount == 1 ? '' : 's'} and sync before midnight.'
        : 'Ensure 100% of today\'s attendance, overtime, and advances are synced and closed before midnight.';

    try {
      // 1. 9:30 AM — Morning Attendance Kickoff
      await _localNotifications.zonedSchedule(
        _idMorningAttendance,
        '📋 Morning Attendance — Trackify',
        'Start marking today\'s labour attendance across your active construction sites.',
        _nextInstanceOfTime(9, 30),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'attendance_morning',
      );

      // 2. 2:00 PM — Mid-Day Shift & Overtime Check
      await _localNotifications.zonedSchedule(
        _idMidDayCheck,
        '⏱️ Mid-Day Attendance Check',
        'Review half-day shifts, site transfers, and unmarked labours for today.',
        _nextInstanceOfTime(14, 0),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'attendance_midday',
      );

      // 3. 6:00 PM — Primary Before Day-End Attendance & Advances Alert
      await _localNotifications.zonedSchedule(
        _idPreDayEndAlert,
        eveningTitle,
        eveningBody,
        _nextInstanceOfTime(18, 0),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'attendance_day_end',
      );

      // 4. 7:30 PM — Final Day-End Wrap-Up Reminder
      await _localNotifications.zonedSchedule(
        _idFinalDayEndAlert,
        finalTitle,
        finalBody,
        _nextInstanceOfTime(19, 30),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'attendance_final_wrapup',
      );

      debugPrint(
        '[NotificationService] Daily supervisor reminders scheduled (9:30 AM, 2:00 PM, 6:00 PM, 7:30 PM).',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] scheduleSupervisorDailyReminders error: $e',
      );
    }
  }

  Future<void> cancelSupervisorDailyReminders() async {
    if (kIsWeb) return;
    try {
      await _localNotifications.cancel(_idMorningAttendance);
      await _localNotifications.cancel(_idMidDayCheck);
      await _localNotifications.cancel(_idPreDayEndAlert);
      await _localNotifications.cancel(_idFinalDayEndAlert);
      debugPrint('[NotificationService] Canceled daily supervisor reminders.');
    } catch (e) {
      debugPrint(
        '[NotificationService] cancelSupervisorDailyReminders error: $e',
      );
    }
  }

  /// Dynamically updates today's scheduled day-end notifications based on live
  /// attendance completion, and immediately alerts the supervisor if it's already
  /// late afternoon/evening (>= 5:00 PM) with unmarked labours remaining.
  Future<void> syncTodayAttendanceReminder({
    required int totalLabours,
    required int markedCount,
  }) async {
    if (kIsWeb || totalLabours <= 0) return;

    final enabled = await isDailyRemindersEnabled();
    if (!enabled) return;

    final unmarkedCount = (totalLabours - markedCount).clamp(0, totalLabours);

    // Refresh today's scheduled 6:00 PM & 7:30 PM alerts with real counts
    await scheduleSupervisorDailyReminders(
      unmarkedCount: unmarkedCount,
      totalLabours: totalLabours,
    );

    // If it's already before day-end (5:00 PM - 10:00 PM) and labours are still unmarked,
    // trigger a rate-limited immediate local alert (at most once every 3 hours).
    final now = DateTime.now();
    if (unmarkedCount > 0 && now.hour >= 17 && now.hour < 22) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastTs = prefs.getInt(_prefLastUnmarkedAlertTs) ?? 0;
        final nowMs = now.millisecondsSinceEpoch;
        const threeHoursMs = 3 * 60 * 60 * 1000;
        if (nowMs - lastTs > threeHoursMs) {
          await _localNotifications.show(
            _idLiveUnmarkedAlert,
            '⚠️ $unmarkedCount Labour${unmarkedCount == 1 ? '' : 's'} Pending Attendance Today',
            'Marked $markedCount/$totalLabours labours so far. Please finish marking today\'s attendance before day end.',
            _attendanceChannelDetails(),
            payload: 'attendance_live_pending',
          );
          await prefs.setInt(_prefLastUnmarkedAlertTs, nowMs);
        }
      } catch (e) {
        debugPrint(
          '[NotificationService] syncTodayAttendanceReminder live alert error: $e',
        );
      }
    }
  }

  /// Sends an immediate test notification so the supervisor can verify alerts work.
  Future<void> sendTestSupervisorReminder() async {
    if (kIsWeb) return;
    try {
      await _localNotifications.show(
        _idTestNotification,
        '✅ Trackify Supervisor Alerts Active',
        'Automatic daily attendance & day-end reminders are enabled (9:30 AM, 2:00 PM, 6:00 PM & 7:30 PM).',
        _attendanceChannelDetails(),
        payload: 'test_reminder',
      );
    } catch (e) {
      debugPrint('[NotificationService] sendTestSupervisorReminder error: $e');
    }
  }

  // ── House Plans Engineer Reminders ─────────────────────────────────────────

  /// Sends a direct Engineer Reminder alert for pending house plans & visits
  Future<void> showPendingPlansReminder({
    required int pendingPlansCount,
    required int pendingDrawingsCount,
    required int visitDueCount,
  }) async {
    if (kIsWeb) return;
    if (pendingPlansCount == 0 &&
        pendingDrawingsCount == 0 &&
        visitDueCount == 0) {
      return;
    }

    final List<String> detailsList = [];
    if (pendingPlansCount > 0) {
      detailsList.add('$pendingPlansCount plan fee pending');
    }
    if (pendingDrawingsCount > 0) {
      detailsList.add('$pendingDrawingsCount drawings in progress');
    }
    if (visitDueCount > 0) detailsList.add('$visitDueCount visits due');

    final summary = detailsList.join(' • ');

    const androidDetails = AndroidNotificationDetails(
      'pending_plans_reminder',
      'House Plans Reminders',
      channelDescription:
          'Alerts and reminders for pending house plans and site visits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      showWhen: true,
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        _idPlansReminder,
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
    if (pendingPlansCount == 0 &&
        pendingDrawingsCount == 0 &&
        visitDueCount == 0) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('last_plans_reminder_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
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

  // ── Operational Sync & Closing Report Alerts ───────────────────────────────

  Future<void> showAttendanceSyncSuccess(int count) async {
    if (kIsWeb || count == 0) return;
    try {
      await _localNotifications.show(
        _idSyncSuccess,
        '☁️ Attendance Synced',
        '$count offline attendance record${count == 1 ? '' : 's'} uploaded safely to Trackify Cloud.',
        _attendanceChannelDetails(
          channelId: 'attendance_sync_updates',
          channelName: 'Sync Notifications',
          channelDescription: 'Offline attendance synchronization status alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] showAttendanceSyncSuccess error: $e');
    }
  }

  Future<void> showOfflineScanQueued(String labourName) async {
    if (kIsWeb) return;
    try {
      await _localNotifications.show(
        _idOfflineScan,
        '📥 Offline Attendance Queued',
        'Attendance saved offline for $labourName. Will sync automatically once internet returns.',
        _attendanceChannelDetails(
          channelId: 'attendance_sync_updates',
          channelName: 'Sync Notifications',
          channelDescription: 'Offline attendance synchronization status alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] showOfflineScanQueued error: $e');
    }
  }

  /// Schedules a daily 6:30 PM Daily Closing Report reminder.
  Future<void> scheduleDailyReportReminder() async {
    if (kIsWeb) return;
    _initTimezone();
    try {
      await _localNotifications.zonedSchedule(
        _idDailyClosingReport,
        '📊 Daily Closing Report Reminder',
        'Generate and save today\'s site closing report (attendance, advances & expenses) before day end.',
        _nextInstanceOfTime(18, 30),
        _attendanceChannelDetails(
          channelId: 'daily_closing_report',
          channelName: 'Daily Closing Reports',
          channelDescription: 'Daily reminders to submit site closing reports',
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_closing_report',
      );
      debugPrint('[NotificationService] Scheduled daily report reminder (6:30 PM).');
    } catch (e) {
      debugPrint('[NotificationService] scheduleDailyReportReminder error: $e');
    }
  }

  Future<void> cancelDailyReportReminder() async {
    if (kIsWeb) return;
    try {
      await _localNotifications.cancel(_idDailyClosingReport);
      debugPrint('[NotificationService] Canceled daily report reminder.');
    } catch (e) {
      debugPrint('[NotificationService] cancelDailyReportReminder error: $e');
    }
  }
}
