import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/features/workout/models/exercise_progress_model.dart';

/// Distinct exercises with completed sets (for exercise picker in graph screen).
final exerciseListProvider = FutureProvider<List<String>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.statsExercises);
  final data = response.data['exercises'] as List<dynamic>;
  return data.cast<String>();
});

/// Date range options.
enum StatsDateRange { last30Days, last90Days, allTime }

/// State for the stats screen (selected exercise + date range).
class StatsState {
  final String? selectedExercise;
  final StatsDateRange dateRange;

  const StatsState({this.selectedExercise, this.dateRange = StatsDateRange.last90Days});

  StatsState copyWith({String? selectedExercise, StatsDateRange? dateRange, bool clearExercise = false}) {
    return StatsState(
      selectedExercise: clearExercise ? null : (selectedExercise ?? this.selectedExercise),
      dateRange: dateRange ?? this.dateRange,
    );
  }
}

class StatsNotifier extends StateNotifier<StatsState> {
  StatsNotifier() : super(const StatsState());

  void selectExercise(String name) => state = state.copyWith(selectedExercise: name);
  void clearExercise() => state = state.copyWith(clearExercise: true);
  void setDateRange(StatsDateRange range) => state = state.copyWith(dateRange: range);
}

final statsNotifierProvider = StateNotifierProvider<StatsNotifier, StatsState>(
  (_) => StatsNotifier(),
);

/// Progress data for the selected exercise and date range.
final exerciseProgressProvider = FutureProvider.family<ExerciseProgressData, ({String name, int? days})>(
  (ref, args) async {
    final response = await ApiClient.instance.get(
      ApiEndpoints.statsExerciseProgress(args.name, days: args.days),
    );
    return ExerciseProgressData.fromJson(response.data as Map<String, dynamic>);
  },
);
