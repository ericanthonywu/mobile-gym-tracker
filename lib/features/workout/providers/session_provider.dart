import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/utils/live_activity_service.dart';
import 'package:gym_tracker/core/utils/notification_service.dart';
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
  final response = await ApiClient.instance.get(ApiEndpoints.sessionsHistory);
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
        final activeEx = session.exercises.firstWhere((e) => !e.isAllCompleted && !e.isSkipped, orElse: () => session.exercises.first);
        LiveActivityService.startLiveActivity(planName: session.planName, currentExercise: activeEx.exerciseName);
      }
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<WorkoutSessionModel?> startSession({
    required String planId,
    bool wasMakeUpSession = false,
    String? skipId,
  }) async {
    final response = await ApiClient.instance.post(ApiEndpoints.sessionsStart, data: {
      'planId': planId,
      'wasMakeUpSession': wasMakeUpSession,
      if (skipId != null) 'skipId': skipId,
    });
    final session = WorkoutSessionModel.fromJson(response.data as Map<String, dynamic>);
    state = AsyncValue.data(session);
    final activeEx = session.exercises.firstWhere((e) => !e.isAllCompleted && !e.isSkipped, orElse: () => session.exercises.first);
    LiveActivityService.startLiveActivity(planName: session.planName, currentExercise: activeEx.exerciseName);
    return session;
  }

  Future<void> recordSet(String sessionId, String setId, {required int reps, double? weightKg}) async {
    await ApiClient.instance.post(
      ApiEndpoints.sessionRecordSet(sessionId, setId),
      data: {'reps': reps, 'weightKg': weightKg},
    );
    await _refresh(sessionId);
  }

  Future<void> skipExercise(String sessionId, String exerciseName) async {
    await ApiClient.instance.post(ApiEndpoints.sessionSkip(sessionId), data: {'exerciseName': exerciseName});
    await _refresh(sessionId);
  }

  Future<void> reEnableExercise(String sessionId, String exerciseName) async {
    await ApiClient.instance.post(ApiEndpoints.sessionReEnable(sessionId), data: {'exerciseName': exerciseName});
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
    if (session.isActive && session.exercises.isNotEmpty) {
      final activeEx = session.exercises.firstWhere((e) => !e.isAllCompleted && !e.isSkipped, orElse: () => session.exercises.first);
      LiveActivityService.updateLiveActivity(currentExercise: activeEx.exerciseName);
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
