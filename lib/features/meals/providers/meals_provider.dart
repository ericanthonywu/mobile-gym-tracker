import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/features/meals/models/meal_model.dart';

final mealsTodayProvider = FutureProvider<List<MealItemModel>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.mealToday);
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => MealItemModel.fromJson(e as Map<String, dynamic>)).toList();
});

final mealSettingsProvider = FutureProvider<List<MealSettingModel>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.mealSettings);
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => MealSettingModel.fromJson(e as Map<String, dynamic>)).toList();
});

final mealSummaryProvider = FutureProvider.family<MealSummaryModel, String>((ref, range) async {
  final response = await ApiClient.instance.get(ApiEndpoints.mealSummary, queryParameters: {'range': range});
  return MealSummaryModel.fromJson(response.data as Map<String, dynamic>);
});
