/// A single data point in an exercise's progress over time.
class ExerciseProgressPoint {
  final DateTime date;
  final double? maxWeightKg;
  final int totalReps;
  final double avgReps;
  final int? totalDurationSeconds;
  final int? maxDurationSeconds;
  final int setCount;

  const ExerciseProgressPoint({
    required this.date,
    this.maxWeightKg,
    required this.totalReps,
    required this.avgReps,
    this.totalDurationSeconds,
    this.maxDurationSeconds,
    required this.setCount,
  });

  factory ExerciseProgressPoint.fromJson(Map<String, dynamic> json) => ExerciseProgressPoint(
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        maxWeightKg: json['maxWeightKg'] != null ? (json['maxWeightKg'] as num).toDouble() : null,
        totalReps: json['totalReps'] as int? ?? 0,
        avgReps: (json['avgReps'] as num?)?.toDouble() ?? 0,
        totalDurationSeconds: json['totalDurationSeconds'] as int?,
        maxDurationSeconds: json['maxDurationSeconds'] as int?,
        setCount: json['setCount'] as int? ?? 0,
      );
}

/// Personal bests for a specific exercise.
class ExercisePersonalBests {
  final double? bestWeightKg;
  final int? bestReps;
  final int? bestDurationSeconds;
  final int totalSessions;
  final String activityType; // 'reps' | 'time'

  const ExercisePersonalBests({
    this.bestWeightKg,
    this.bestReps,
    this.bestDurationSeconds,
    required this.totalSessions,
    this.activityType = 'reps',
  });

  bool get isTimeBased => activityType == 'time' || (bestDurationSeconds != null && bestDurationSeconds! > 0);

  factory ExercisePersonalBests.fromJson(Map<String, dynamic> json) => ExercisePersonalBests(
        bestWeightKg: json['bestWeightKg'] != null ? (json['bestWeightKg'] as num).toDouble() : null,
        bestReps: json['bestReps'] as int?,
        bestDurationSeconds: json['bestDurationSeconds'] as int?,
        totalSessions: json['totalSessions'] as int? ?? 0,
        activityType: json['activityType'] as String? ?? 'reps',
      );
}

/// Full progress data for a given exercise.
class ExerciseProgressData {
  final String exerciseName;
  final List<ExerciseProgressPoint> progress;
  final ExercisePersonalBests bests;

  const ExerciseProgressData({
    required this.exerciseName,
    required this.progress,
    required this.bests,
  });

  factory ExerciseProgressData.fromJson(Map<String, dynamic> json) => ExerciseProgressData(
        exerciseName: json['exerciseName'] as String,
        progress: (json['progress'] as List<dynamic>? ?? [])
            .map((e) => ExerciseProgressPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        bests: ExercisePersonalBests.fromJson(json['bests'] as Map<String, dynamic>? ?? {}),
      );
}
