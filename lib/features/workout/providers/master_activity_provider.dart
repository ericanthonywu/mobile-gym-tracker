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

/// Search master activities by query string — debounced via UI.
final activitySearchProvider = FutureProvider.family<List<MasterActivityModel>, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return ref.watch(masterActivitiesProvider).value ?? [];
  }
  final response = await ApiClient.instance.get(ApiEndpoints.activitySearch(query));
  final data = response.data as List<dynamic>;
  return data.map((e) => MasterActivityModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// Create or find a master activity by name (idempotent).
Future<MasterActivityModel> findOrCreateActivity(String name) async {
  final response = await ApiClient.instance.post(ApiEndpoints.activities, data: {'name': name.trim()});
  return MasterActivityModel.fromJson(response.data as Map<String, dynamic>);
}
