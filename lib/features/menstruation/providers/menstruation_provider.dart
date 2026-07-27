import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/features/menstruation/models/menstruation_log_model.dart';

final menstruationLogsProvider = FutureProvider<List<MenstruationLogModel>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.menstruation);
  final data = response.data['data'] as List;
  return data.map((e) => MenstruationLogModel.fromJson(e as Map<String, dynamic>)).toList();
});

class MenstruationController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  MenstruationController(this.ref) : super(const AsyncData(null));

  Future<void> addLog({
    required DateTime startDate,
    DateTime? endDate,
    String? flowIntensity,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      await ApiClient.instance.post(ApiEndpoints.menstruation, data: {
        'start_date': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
        if (flowIntensity != null) 'flow_intensity': flowIntensity,
        if (notes != null) 'notes': notes,
      });
      ref.invalidate(menstruationLogsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateLog({
    required String id,
    DateTime? startDate,
    DateTime? endDate,
    String? flowIntensity,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      await ApiClient.instance.put(ApiEndpoints.menstruationById(id), data: {
        if (startDate != null) 'start_date': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
        if (flowIntensity != null) 'flow_intensity': flowIntensity,
        if (notes != null) 'notes': notes,
      });
      ref.invalidate(menstruationLogsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteLog(String id) async {
    state = const AsyncLoading();
    try {
      await ApiClient.instance.delete(ApiEndpoints.menstruationById(id));
      ref.invalidate(menstruationLogsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final menstruationControllerProvider = StateNotifierProvider<MenstruationController, AsyncValue<void>>((ref) {
  return MenstruationController(ref);
});
