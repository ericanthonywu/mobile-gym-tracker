import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/features/workout/models/master_activity_model.dart';

/// All master activities (cached, refreshed manually).
final masterActivitiesProvider = FutureProvider<List<MasterActivityModel>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.activities);
  final data = response.data as List<dynamic>;
  return data.map((e) => MasterActivityModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// All distinct primary muscles with exercise counts.
/// Returns: [{ muscle_name: 'chest', exercise_count: 42 }, ...]
final activityMusclesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.activityMuscles);
  final data = response.data as List<dynamic>;
  return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// Activities filtered by primary muscle group.
/// Pass [includeSecondary] = true to include exercises where muscle is secondary.
final activitiesByMuscleProvider =
    FutureProvider.family<List<MasterActivityModel>, ({String muscle, bool includeSecondary})>(
        (ref, args) async {
  final response = await ApiClient.instance.get(
    ApiEndpoints.activitiesByMuscle(args.muscle, includeSecondary: args.includeSecondary),
  );
  final data = response.data as List<dynamic>;
  return data.map((e) => MasterActivityModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// Search master activities by query string — debounced via UI.
/// Optionally pass a [muscle] filter alongside the text query.
final activitySearchProvider =
    FutureProvider.family<List<MasterActivityModel>, ({String query, String? muscle})>(
        (ref, args) async {
  final query = args.query.trim();
  final muscle = args.muscle;

  if (query.isEmpty && (muscle == null || muscle.isEmpty)) {
    return ref.watch(masterActivitiesProvider).value ?? [];
  }

  final response = await ApiClient.instance
      .get(ApiEndpoints.activitySearch(query, muscle: muscle));
  final data = response.data as List<dynamic>;
  return data.map((e) => MasterActivityModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// Legacy search provider — accepts a plain String query with no muscle filter.
/// Kept for backward compatibility with existing search widgets.
final activitySearchLegacyProvider =
    FutureProvider.family<List<MasterActivityModel>, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return ref.watch(masterActivitiesProvider).value ?? [];
  }
  final response =
      await ApiClient.instance.get(ApiEndpoints.activitySearch(query));
  final data = response.data as List<dynamic>;
  return data.map((e) => MasterActivityModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// Create or find a master activity by name (idempotent).
Future<MasterActivityModel> findOrCreateActivity(String name) async {
  final response = await ApiClient.instance
      .post(ApiEndpoints.activities, data: {'name': name.trim()});
  return MasterActivityModel.fromJson(response.data as Map<String, dynamic>);
}
