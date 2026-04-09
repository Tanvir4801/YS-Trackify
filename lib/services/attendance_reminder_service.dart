import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/date_utils.dart';
import 'hive_service.dart';

class AttendanceReminderService {
  AttendanceReminderService({required HiveService hiveService}) : _hiveService = hiveService;

  final HiveService _hiveService;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1001;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _requestPermissions();
    await _scheduleOrCancelForToday();
  }

  Future<void> runDailyAttendanceCheck() async {
    await _scheduleOrCancelForToday();
  }

  Future<void> _scheduleOrCancelForToday() async {
    final hasMarked = _isTodayAttendanceMarked();

    if (hasMarked) {
      await _plugin.cancel(_dailyReminderId);
      return;
    }

    final scheduledTime = _next9Am();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'attendance_reminder_channel',
        'Attendance Reminder',
        channelDescription: 'Daily reminder to mark attendance',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Reminder',
        'Mark today\'s attendance',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'attendance-reminder',
      );
    } on PlatformException catch (error) {
      if (error.code != 'exact_alarms_not_permitted') {
        rethrow;
      }

      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Reminder',
        'Mark today\'s attendance',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'attendance-reminder',
      );
    }
  }

  bool _isTodayAttendanceMarked() {
    final dateKey = AppDateUtils.toDateKey(DateTime.now());
    return _hiveService.getAttendanceForDate(dateKey).isNotEmpty;
  }

  tz.TZDateTime _next9Am() {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);

    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    return target;
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      await _plugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }
}
