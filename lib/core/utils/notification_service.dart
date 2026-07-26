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

  /// Special one-shot graduation notification — Aug 9 at 06:00 WIB.
  static const int _graduationNotificationId = 9090;

  /// Callback fired when the graduation notification is tapped.
  /// Set this from main() or the root widget to navigate to GraduationScreen.
  static void Function()? onGraduationTap;

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

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final id = response.id;
        // Fires for both the special graduation notification and regular reminders
        final isGraduationNotif = id == _graduationNotificationId;
        final isReminder = id != null &&
            id >= _weekdayReminder4pm &&
            id <= _weekendReminder10am + 40;
        // Only open graduation screen from Aug 9 at or after 06:00 WIB
        final now = DateTime.now();
        final isUnlocked = now.month == 8 && now.day == 9 && now.hour >= 6;
        if ((isGraduationNotif || isReminder) && isUnlocked) {
          onGraduationTap?.call();
        }
      },
    );
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
  // Ongoing Active Workout Notification
  // ---------------------------------------------------------------------------
  static const int _ongoingWorkoutId = 3001;

  /// Show or update active ongoing workout notification.
  static Future<void> showOngoingWorkoutNotification({
    required String planName,
    required String elapsedStr,
    String? currentExercise,
  }) async {
    final bodyStr = currentExercise != null && currentExercise.isNotEmpty
        ? '⏱ Elapsed: $elapsedStr • $currentExercise'
        : '⏱ Elapsed: $elapsedStr • Tap to return to workout';

    await _plugin.show(
      _ongoingWorkoutId,
      '🏋️ Active Workout: $planName',
      bodyStr,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }

  static Future<void> cancelOngoingWorkoutNotification() async {
    await _plugin.cancel(_ongoingWorkoutId);
  }

  // ---------------------------------------------------------------------------
  // Daily Reminders
  // ---------------------------------------------------------------------------

  // Aug 9 graduation date (WIB)
  static final DateTime _graduationDate = DateTime(2026, 8, 9);

  /// Schedule recurring daily reminders with motivational copy.
  /// - Before Aug 9: graduation countdown encouragement
  /// - On Aug 9: celebration message
  /// - After Aug 9: general fat-loss & fitness motivation
  static Future<void> scheduleDailyReminders() async {
    await cancelAllReminders();

    // One-shot graduation notification: Aug 9 at 06:00 WIB 🎓
    await scheduleGraduationNotification();

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

  static _ReminderCopy _buildCopy(int weekday, int hour) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final graduation = DateTime(_graduationDate.year, _graduationDate.month, _graduationDate.day);
    final daysLeft = graduation.difference(today).inDays;
    final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;

    // 🎓 Graduation day — celebrate!
    if (daysLeft == 0) {
      return _ReminderCopy(
        title: '🎓 Congrats, Vivian!',
        body: 'Today’s your big day, Vivian! 🎉 Celebrate the hard work you’ve put in – you’ve earned it.',
      );
    }

    // After graduation — fat‑loss & general maintenance
    if (daysLeft < 0) {
      if (isWeekend) {
        final weekendAfter = [
          '☀️ Good morning, Vivian! Log your weight & keep the momentum 📊',
          '🌸 Weekend check‑in! Consistency keeps the results flowing 💪',
        ];
        return _ReminderCopy(
          title: weekendAfter[weekday % weekendAfter.length],
          body: 'Track your weight and stay on your cut journey! Keep it chill and steady.',
        );
      }
      final afterPool = [
        _ReminderCopy(
          title: '💪 Gym vibes, Vivian!',
          body: 'Keep it casual – a strong body is a lifestyle, not a deadline.',
        ),
        _ReminderCopy(
          title: '🔥 Keep training!',
          body: 'Fat loss is a marathon. One workout at a time, no rush.',
        ),
        _ReminderCopy(
          title: '🏋️ Your rules!',
          body: "Every session counts on your cut journey. Let's enjoy the grind",
        ),
        _ReminderCopy(
          title: '⚡ Stay consistent, Vivian!',
          body: 'Progress shows up even when invisible. Show up today, keep it easy.',
        ),
        _ReminderCopy(
          title: '🌟 You’ve got this!',
          body: "Discipline is doing it even when you don\'t feel like it. Take it easy and train.",
        ),
      ];
      return afterPool[(today.day + hour) % afterPool.length];
    }

    // Before graduation — countdown motivation (casual, no pressure)
    if (isWeekend) {
      final weekendBefore = [
        _ReminderCopy(
          title: '☀️ Good morning, Vivian!',
          body: 'Log your weight – watch the glow‑up unfold. No rush, just steady.',
        ),
        _ReminderCopy(
          title: '🌸 Weekend check‑in!',
          body: 'Your graduation body builds one day at a time. Keep it relaxed! 💕',
        ),
      ];
      return weekendBefore[weekday % weekendBefore.length];
    }

    // Weekday before graduation — rotation pool (friendly, casual)
    final beforePool = [
      _ReminderCopy(
        title: '💪 Time to train, Vivian!',
        body: 'Just $daysLeft days till graduation – every workout is a friendly gift to yourself 🎁',
      ),
      _ReminderCopy(
        title: '🏋️ Gym o\'clock!',
        body: 'Look and feel great on graduation day. One set at a time, no pressure.',
      ),
      _ReminderCopy(
        title: '⚡ Let\'s go, Vivian!',
        body: 'The gym is waiting – and so is your best self. $daysLeft days to graduation, stay chill!',
      ),
      _ReminderCopy(
        title: '🎯 Showing up matters!',
        body: "Goal: feel confident and strong on graduation day. Start with today's relaxed session!",
      ),
      _ReminderCopy(
        title: '🌟 Keep building, Vivian!',
        body: "Steady progress every week. Graduation is $daysLeft days away – enjoy the journey!",
      ),
    ];
    return beforePool[(today.day + hour) % beforePool.length];
  }

  static Future<void> _scheduleWeekdayReminder(int id, int hour, int minute, String dayName) async {
    final day = _dayFromName(dayName);
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = _nextWeekday(now, day, hour, minute);
    final copy = _buildCopy(day, hour);

    await _plugin.zonedSchedule(
      id,
      copy.title,
      copy.body,
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

  /// Schedule the one-shot graduation notification for Aug 9 at 06:00 WIB.
  /// Silently skips if Aug 9 is already past.
  static Future<void> scheduleGraduationNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    final graduationFire = tz.TZDateTime(tz.local, 2026, 8, 9, 6, 0);

    // Don't schedule if the date has already passed
    if (now.isAfter(graduationFire)) return;

    await _plugin.zonedSchedule(
      _graduationNotificationId,
      '🎓 Happy Graduation Day, Vivian!',
      'You made it! Tap for your special message 💛',
      graduationFire,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAllReminders() async {
    final ids = [
      _graduationNotificationId,
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

/// Internal helper for notification copy.
class _ReminderCopy {
  final String title;
  final String body;
  const _ReminderCopy({required this.title, required this.body});
}
