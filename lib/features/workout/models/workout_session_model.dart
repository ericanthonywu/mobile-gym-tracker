class SessionSetModel {
  final String id;
  final String sessionId;
  final String exerciseName;
  final int sortOrder;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final bool isSkipped;
  final bool isCompleted;
  final int restDurationSeconds;

  const SessionSetModel({
    required this.id,
    required this.sessionId,
    required this.exerciseName,
    required this.sortOrder,
    required this.setNumber,
    this.reps,
    this.weightKg,
    required this.isSkipped,
    required this.isCompleted,
    required this.restDurationSeconds,
  });

  factory SessionSetModel.fromJson(Map<String, dynamic> json) => SessionSetModel(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        exerciseName: json['exercise_name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        setNumber: json['set_number'] as int,
        reps: json['reps'] as int?,
        weightKg: json['weight_kg'] != null ? double.tryParse(json['weight_kg'].toString()) : null,
        isSkipped: json['is_skipped'] as bool? ?? false,
        isCompleted: json['is_completed'] as bool? ?? false,
        restDurationSeconds: json['rest_duration_seconds'] as int? ?? 120,
      );
}

class ExerciseSessionModel {
  final String exerciseName;
  final int sortOrder;
  final List<SessionSetModel> sets;

  const ExerciseSessionModel({
    required this.exerciseName,
    required this.sortOrder,
    required this.sets,
  });

  bool get isAllCompleted => sets.every((s) => s.isCompleted || s.isSkipped);
  bool get isSkipped => sets.every((s) => s.isSkipped);
  bool get isActive => !isAllCompleted;
  int get completedSets => sets.where((s) => s.isCompleted).length;
  int get totalSets => sets.length;

  factory ExerciseSessionModel.fromJson(Map<String, dynamic> json) => ExerciseSessionModel(
        exerciseName: json['exerciseName'] as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
        sets: (json['sets'] as List<dynamic>? ?? [])
            .map((s) => SessionSetModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class WorkoutSessionModel {
  final String id;
  final String? planId;
  final String planName;
  final String status; // active | completed | cancelled
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? notes;
  final bool wasMakeUpSession;
  final List<ExerciseSessionModel> exercises;

  const WorkoutSessionModel({
    required this.id,
    this.planId,
    required this.planName,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.notes,
    required this.wasMakeUpSession,
    required this.exercises,
  });

  bool get isActive => status == 'active';
  Duration? get duration => completedAt != null ? completedAt!.difference(startedAt) : null;

  /// Next incomplete set across all exercises (in order)
  SessionSetModel? get nextSet {
    for (final ex in exercises) {
      if (ex.isSkipped) continue;
      for (final s in ex.sets) {
        if (!s.isCompleted && !s.isSkipped) return s;
      }
    }
    return null;
  }

  factory WorkoutSessionModel.fromJson(Map<String, dynamic> json) => WorkoutSessionModel(
        id: json['id'] as String,
        planId: json['plan_id'] as String?,
        planName: json['plan_name'] as String,
        status: json['status'] as String,
        startedAt: (DateTime.tryParse(json['started_at'] as String? ?? '') ?? DateTime.now()).toLocal(),
        completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String)?.toLocal() : null,
        notes: json['notes'] as String?,
        wasMakeUpSession: json['was_make_up_session'] as bool? ?? false,
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => ExerciseSessionModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
