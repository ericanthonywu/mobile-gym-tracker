/// Centralized API endpoint constants.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';

  // Workout Plans
  static const String workoutPlans = '/workout-plans';
  static String workoutPlanById(String id) => '/workout-plans/$id';

  // Schedule
  static const String schedule = '/schedule';
  static const String scheduleToday = '/schedule/today';
  static const String scheduleNotificationCheck = '/schedule/notification-check';
  static const String scheduleSkipToday = '/schedule/skip-today';
  static const String scheduleRestToday = '/schedule/rest-today';
  static String scheduleDismissSkip(String skipId) => '/schedule/dismiss-skip/$skipId';

  // Sessions
  static const String sessionsStart = '/sessions/start';
  static const String sessionsCardio = '/sessions/cardio';
  static const String sessionsActive = '/sessions/active';
  static const String sessionsHistory = '/sessions/history';
  static String sessionById(String id) => '/sessions/$id';
  static String sessionRecordSet(String id, String setId) => '/sessions/$id/sets/$setId';
  static String sessionSkip(String id) => '/sessions/$id/skip';
  static String sessionReEnable(String id) => '/sessions/$id/re-enable';
  static String sessionSkippedExercises(String id) => '/sessions/$id/skipped-exercises';
  static String sessionComplete(String id) => '/sessions/$id/complete';
  static String sessionCancel(String id) => '/sessions/$id/cancel';

  // Weight
  static const String weightList = '/weight';
  static const String weightLatest = '/weight/latest';
  static const String weightChart = '/weight/chart';
  static const String weightSummary = '/weight/summary';
  static String weightById(String id) => '/weight/$id';

  // Meals
  static const String mealSettings = '/meals/settings';
  static String mealSettingById(String id) => '/meals/settings/$id';
  static const String mealToday = '/meals/today';
  static const String mealToggle = '/meals/toggle';
  static const String mealSummary = '/meals/summary';

  // Master Activities
  static const String activities = '/activities';
  static String activitySearch(String q) => '/activities/search?q=${Uri.encodeComponent(q)}';

  // Stats / Progress Graphs
  static const String statsExercises = '/stats/exercises';
  static String statsExerciseProgress(String name, {int? days}) {
    final base = '/stats/exercises/${Uri.encodeComponent(name)}/progress';
    return days != null ? '$base?days=$days' : base;
  }
}
