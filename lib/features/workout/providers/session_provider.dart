import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/utils/live_activity_service.dart';
import 'package:gym_tracker/core/utils/notification_service.dart';
import 'package:gym_tracker/features/workout/models/set_comparison_model.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';

// ---------------------------------------------------------------------------
// Active session
// ---------------------------------------------------------------------------

final activeSessionProvider = FutureProvider<WorkoutSessionModel?>((ref) async {
  try {
    final response = await ApiClient.instance.get(ApiEndpoints.sessionsActive);
    return WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    return null; // 404 = no active session
  }
});

// ---------------------------------------------------------------------------
// Session history
// ---------------------------------------------------------------------------

final sessionHistoryProvider = FutureProvider<List<WorkoutSessionModel>>((ref) async {
  final response = await ApiClient.instance.get('${ApiEndpoints.sessionsHistory}?limit=100');
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => WorkoutSessionModel.fromJson(e as Map<String, dynamic>)).toList();
});

final recentSessionsProvider = FutureProvider<List<WorkoutSessionModel>>((ref) async {
  final response = await ApiClient.instance.get('${ApiEndpoints.sessionsHistory}?limit=5');
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => WorkoutSessionModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ---------------------------------------------------------------------------
// Session detail by ID
// ---------------------------------------------------------------------------

final sessionDetailProvider = FutureProvider.family<WorkoutSessionModel, String>((ref, id) async {
  final response = await ApiClient.instance.get(ApiEndpoints.sessionById(id));
  return WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
});

// ---------------------------------------------------------------------------
// Last completed session for a plan (used by dashboard to show real history)
// ---------------------------------------------------------------------------

final lastSessionByPlanProvider = FutureProvider.family<WorkoutSessionModel?, String>((ref, planId) async {
  try {
    final response = await ApiClient.instance.get(ApiEndpoints.sessionLastByPlan(planId));
    return WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    return null; // 404 = no previous session for this plan
  }
});

// ---------------------------------------------------------------------------
// Active session state notifier (for UI tracking during workout)
// ---------------------------------------------------------------------------

class ActiveSessionNotifier extends StateNotifier<AsyncValue<WorkoutSessionModel?>> {
  ActiveSessionNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.sessionsActive);
      final session = WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
      state = AsyncValue.data(session);
      if (session.isActive) {
        _syncLiveActivity(session);
      }
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  /// Start a session from a plan (plan-based or custom-modified or free-form Quick Workout).
  ///
  /// - [planId] — optional. If null, must provide [exercises] and [planName].
  /// - [exercises] — optional inline exercise list. If provided alongside [planId], overrides the plan template.
  /// - [planName] — optional. Used as the session name when [planId] is null.
  /// - [wasMakeUpSession] — flag for skipped day make-up sessions.
  /// - [skipId] — skipped day entry ID to mark completed.
  Future<WorkoutSessionModel?> startSession({
    String? planId,
    String? planName,
    bool wasMakeUpSession = false,
    String? skipId,
    List<Map<String, dynamic>>? exercises,
  }) async {
    final response = await ApiClient.instance.post(ApiEndpoints.sessionsStart, data: {
      if (planId != null) 'planId': planId,
      if (planName != null) 'planName': planName,
      'wasMakeUpSession': wasMakeUpSession,
      if (skipId != null) 'skipId': skipId,
      if (exercises != null) 'exercises': exercises,
    });
    final session = WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
    state = AsyncValue.data(session);

    final nextSet = session.nextSet;
    String activeExName = '';
    int? currentSet;
    int? totalSets;
    if (nextSet != null) {
      activeExName = nextSet.exerciseName;
      currentSet = nextSet.setNumber;
      final ex = session.exercises.firstWhere((e) => e.exerciseName == nextSet.exerciseName, orElse: () => session.exercises.first);
      totalSets = ex.totalSets;
    } else if (session.exercises.isNotEmpty) {
      activeExName = session.exercises.first.exerciseName;
      totalSets = session.exercises.first.totalSets;
    }

    liveActivityError = await LiveActivityService.startLiveActivity(
      planName: session.planName,
      currentExercise: activeExName,
      currentSet: currentSet,
      totalSets: totalSets,
    );
    return session;
  }

  /// Non-null if the last startLiveActivity call failed — contains the error message.
  String? liveActivityError;

  Future<SetComparisonModel?> recordSet(String sessionId, String setId, {int? reps, double? weightKg, int? durationSeconds}) async {
    final response = await ApiClient.instance.post(
      ApiEndpoints.sessionRecordSet(sessionId, setId),
      data: {
        if (reps != null) 'reps': reps,
        if (weightKg != null) 'weightKg': weightKg,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      },
    );
    final data = response.data as Map<String, dynamic>;
    await _refresh(sessionId);

    final compJson = data['comparison'] as Map<String, dynamic>?;
    return compJson != null ? SetComparisonModel.fromJson(compJson) : null;
  }

  Future<void> skipExercise(String sessionId, String exerciseName) async {
    await ApiClient.instance.post(ApiEndpoints.sessionSkip(sessionId), data: {'exerciseName': exerciseName});
    await _refresh(sessionId);
  }

  Future<void> reEnableExercise(String sessionId, String exerciseName) async {
    await ApiClient.instance.post(ApiEndpoints.sessionReEnable(sessionId), data: {'exerciseName': exerciseName});
    await _refresh(sessionId);
  }

  /// Add a new exercise to an already-active session (mid-session custom addition).
  Future<void> addExercise(
    String sessionId, {
    required String name,
    required int targetSets,
    int targetReps = 0,
    String activityType = 'reps',
    int? targetDurationSeconds,
  }) async {
    await ApiClient.instance.post(
      ApiEndpoints.sessionAddExercise(sessionId),
      data: {
        'name': name,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'activityType': activityType,
        if (targetDurationSeconds != null) 'targetDurationSeconds': targetDurationSeconds,
      },
    );
    await _refresh(sessionId);
  }

  Future<WorkoutSessionModel> completeSession(String sessionId, {String? notes}) async {
    final response = await ApiClient.instance.post(
      ApiEndpoints.sessionComplete(sessionId),
      data: {'notes': notes ?? ''},
    );
    final session = WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
    state = const AsyncValue.data(null);
    NotificationService.cancelOngoingWorkoutNotification();
    LiveActivityService.stopLiveActivity();
    return session;
  }

  Future<void> cancelSession(String sessionId) async {
    await ApiClient.instance.post(ApiEndpoints.sessionCancel(sessionId));
    state = const AsyncValue.data(null);
    NotificationService.cancelOngoingWorkoutNotification();
    LiveActivityService.stopLiveActivity();
  }

  Future<List<String>> getSkippedExercises(String sessionId) async {
    final response = await ApiClient.instance.get(ApiEndpoints.sessionSkippedExercises(sessionId));
    return List<String>.from(response.data['skippedExercises'] as List);
  }

  Future<void> _refresh(String sessionId) async {
    final response = await ApiClient.instance.get(ApiEndpoints.sessionById(sessionId));
    final session = WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
    state = AsyncValue.data(session);
    if (session.isActive) {
      _syncLiveActivity(session);
    }
  }

  void _syncLiveActivity(WorkoutSessionModel session) {
    if (!session.isActive) return;
    final nextSet = session.nextSet;
    if (nextSet != null) {
      final ex = session.exercises.firstWhere((e) => e.exerciseName == nextSet.exerciseName, orElse: () => session.exercises.first);
      LiveActivityService.updateLiveActivity(
        currentExercise: nextSet.exerciseName,
        currentSet: nextSet.setNumber,
        totalSets: ex.totalSets,
      );
    } else if (session.exercises.isNotEmpty) {
      final ex = session.exercises.first;
      LiveActivityService.updateLiveActivity(
        currentExercise: ex.exerciseName,
        currentSet: ex.completedSets,
        totalSets: ex.totalSets,
      );
    }
  }
}

final activeSessionNotifierProvider = StateNotifierProvider<ActiveSessionNotifier, AsyncValue<WorkoutSessionModel?>>(
  (_) => ActiveSessionNotifier(),
);

/// Delete a completed workout session and refresh relevant providers.
Future<void> deleteWorkoutSession(WidgetRef ref, String id) async {
  await ApiClient.instance.delete(ApiEndpoints.sessionById(id));
  ref.invalidate(sessionHistoryProvider);
  ref.invalidate(recentSessionsProvider);
  ref.invalidate(sessionDetailProvider(id));
}

/// Mark today as rest day and refresh providers.
Future<WorkoutSessionModel> markRestDayToday(WidgetRef ref, {String? notes}) async {
  final response = await ApiClient.instance.post(ApiEndpoints.scheduleRestToday, data: {
    if (notes != null) 'notes': notes,
  });
  final session = WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
  ref.invalidate(sessionHistoryProvider);
  ref.invalidate(recentSessionsProvider);
  return session;
}

/// Log a cardio activity and refresh providers.
Future<WorkoutSessionModel> logCardioSession(
  WidgetRef ref, {
  required String activityName,
  int? durationSeconds,
  double? speed,
  double? incline,
  String? notes,
}) async {
  final response = await ApiClient.instance.post(ApiEndpoints.sessionsCardio, data: {
    'activityName': activityName,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (speed != null) 'speed': speed,
    if (incline != null) 'incline': incline,
    if (notes != null) 'notes': notes,
  });
  final session = WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
  ref.invalidate(sessionHistoryProvider);
  ref.invalidate(recentSessionsProvider);
  return session;
}
