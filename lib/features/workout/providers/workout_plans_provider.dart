import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/features/workout/models/workout_plan_model.dart';

final workoutPlansProvider = FutureProvider<List<WorkoutPlanModel>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.workoutPlans);
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => WorkoutPlanModel.fromJson(e as Map<String, dynamic>)).toList();
});

final workoutPlanByIdProvider = FutureProvider.family<WorkoutPlanModel, String>((ref, id) async {
  final response = await ApiClient.instance.get(ApiEndpoints.workoutPlanById(id));
  return WorkoutPlanModel.fromJson(response.data as Map<String, dynamic>);
});
