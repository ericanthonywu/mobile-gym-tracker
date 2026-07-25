import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// OS-level notification service for:
/// - Daily workout reminders (weekday 4/5/6pm, weekend 9/10am)
/// - Rest timer alerts (fires even when app is in background/killed)
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _restTimerId = 1001;
  static const int _weekdayReminder4pm = 2001;
  static const int _weekdayReminder5pm = 2002;
  static const int _weekdayReminder6pm = 2003;
  static const int _weekendReminder9am = 2004;
  static const int _weekendReminder10am = 2005;

  static bool _initialized = false;

  /// Call once from main() before runApp()
  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Request iOS notification permission.
  static Future<bool?> requestPermission() async {
    return _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Rest Timer
  // ---------------------------------------------------------------------------

  /// Schedule a one-shot notification for when the rest period ends.
  static Future<void> scheduleRestTimer({
    required int durationSeconds,
    required String exerciseName,
    int? nextSetNumber,
  }) async {
    // Cancel any existing rest timer first
    await cancelRestTimer();

    final fireTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: durationSeconds));
    final setMsg = nextSetNumber != null ? ' — Set $nextSetNumber is up next!' : '';

    await _plugin.zonedSchedule(
      _restTimerId,
      '⏱ Rest Over! Time to Go 💪',
      'Get back to $exerciseName$setMsg',
      fireTime,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelRestTimer() async {
    await _plugin.cancel(_restTimerId);
  }

  // ---------------------------------------------------------------------------
  // Daily Reminders
  // ---------------------------------------------------------------------------

  /// Schedule recurring daily reminders.
  /// Call once on first launch / after login.
  static Future<void> scheduleDailyReminders() async {
    await cancelAllReminders();

    // Weekday: 4pm (Mon-Fri)
    await _scheduleWeekdayReminder(_weekdayReminder4pm, 16, 0, 'Monday');
    await _scheduleWeekdayReminder(_weekdayReminder4pm + 10, 16, 0, 'Tuesday');
    await _scheduleWeekdayReminder(_weekdayReminder4pm + 20, 16, 0, 'Wednesday');
    await _scheduleWeekdayReminder(_weekdayReminder4pm + 30, 16, 0, 'Thursday');
    await _scheduleWeekdayReminder(_weekdayReminder4pm + 40, 16, 0, 'Friday');

    // Weekday: 5pm (Mon-Fri)
    await _scheduleWeekdayReminder(_weekdayReminder5pm, 17, 0, 'Monday');
    await _scheduleWeekdayReminder(_weekdayReminder5pm + 10, 17, 0, 'Tuesday');
    await _scheduleWeekdayReminder(_weekdayReminder5pm + 20, 17, 0, 'Wednesday');
    await _scheduleWeekdayReminder(_weekdayReminder5pm + 30, 17, 0, 'Thursday');
    await _scheduleWeekdayReminder(_weekdayReminder5pm + 40, 17, 0, 'Friday');

    // Weekday: 6pm (Mon-Fri)
    await _scheduleWeekdayReminder(_weekdayReminder6pm, 18, 0, 'Monday');
    await _scheduleWeekdayReminder(_weekdayReminder6pm + 10, 18, 0, 'Tuesday');
    await _scheduleWeekdayReminder(_weekdayReminder6pm + 20, 18, 0, 'Wednesday');
    await _scheduleWeekdayReminder(_weekdayReminder6pm + 30, 18, 0, 'Thursday');
    await _scheduleWeekdayReminder(_weekdayReminder6pm + 40, 18, 0, 'Friday');

    // Weekend: 9am (Sat-Sun)
    await _scheduleWeekdayReminder(_weekendReminder9am, 9, 0, 'Saturday');
    await _scheduleWeekdayReminder(_weekendReminder9am + 10, 9, 0, 'Sunday');

    // Weekend: 10am (Sat-Sun)
    await _scheduleWeekdayReminder(_weekendReminder10am, 10, 0, 'Saturday');
    await _scheduleWeekdayReminder(_weekendReminder10am + 10, 10, 0, 'Sunday');
  }

  static Future<void> _scheduleWeekdayReminder(int id, int hour, int minute, String dayName) async {
    final day = _dayFromName(dayName);
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = _nextWeekday(now, day, hour, minute);

    final bool isWeekend = day == DateTime.saturday || day == DateTime.sunday;
    final title = isWeekend
        ? '☀️ Good morning, Vivian!'
        : '💪 Time to hit the gym, Vivian!';
    final body = isWeekend
        ? 'Don\'t forget to track your weight today!'
        : 'Your workout is waiting. Let\'s go!';

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static int _dayFromName(String name) {
    const map = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };
    return map[name] ?? DateTime.monday;
  }

  static tz.TZDateTime _nextWeekday(tz.TZDateTime from, int weekday, int hour, int minute) {
    var date = tz.TZDateTime(tz.local, from.year, from.month, from.day, hour, minute);
    while (date.weekday != weekday || date.isBefore(from)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  static Future<void> cancelAllReminders() async {
    final ids = [
      _weekdayReminder4pm, _weekdayReminder4pm + 10, _weekdayReminder4pm + 20,
      _weekdayReminder4pm + 30, _weekdayReminder4pm + 40,
      _weekdayReminder5pm, _weekdayReminder5pm + 10, _weekdayReminder5pm + 20,
      _weekdayReminder5pm + 30, _weekdayReminder5pm + 40,
      _weekdayReminder6pm, _weekdayReminder6pm + 10, _weekdayReminder6pm + 20,
      _weekdayReminder6pm + 30, _weekdayReminder6pm + 40,
      _weekendReminder9am, _weekendReminder9am + 10,
      _weekendReminder10am, _weekendReminder10am + 10,
    ];
    for (final id in ids) { await _plugin.cancel(id); }
  }
}
