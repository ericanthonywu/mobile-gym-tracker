import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/features/weight/models/weight_log_model.dart';

final weightLatestProvider = FutureProvider<WeightLogModel?>((ref) async {
  try {
    final response = await ApiClient.instance.get(ApiEndpoints.weightLatest);
    if (response.data == null) return null;
    return WeightLogModel.fromJson(response.data as Map<String, dynamic>);
  } catch (_) { return null; }
});

final weightChartProvider = FutureProvider.family<List<WeightChartPoint>, String>((ref, range) async {
  final response = await ApiClient.instance.get(ApiEndpoints.weightChart, queryParameters: {'range': range});
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => WeightChartPoint.fromJson(e as Map<String, dynamic>)).toList();
});

final weightSummaryProvider = FutureProvider.family<WeightSummaryModel, String>((ref, range) async {
  final response = await ApiClient.instance.get(ApiEndpoints.weightSummary, queryParameters: {'range': range});
  return WeightSummaryModel.fromJson(response.data as Map<String, dynamic>);
});

final weightListProvider = FutureProvider<List<WeightLogModel>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.weightList);
  final data = response.data['data'] as List<dynamic>;
  return data.map((e) => WeightLogModel.fromJson(e as Map<String, dynamic>)).toList();
});
