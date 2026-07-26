class SessionSetModel {
  final String id;
  final String sessionId;
  final String exerciseName;
  final int sortOrder;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final int? defaultReps;
  final double? defaultWeightKg;
  final int? defaultDurationSeconds;
  final bool isSkipped;
  final bool isCompleted;
  final int restDurationSeconds;
  final String activityType; // 'reps' | 'time'

  const SessionSetModel({
    required this.id,
    required this.sessionId,
    required this.exerciseName,
    required this.sortOrder,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.defaultReps,
    this.defaultWeightKg,
    this.defaultDurationSeconds,
    required this.isSkipped,
    required this.isCompleted,
    required this.restDurationSeconds,
    this.activityType = 'reps',
  });

  bool get isTimeBased => activityType == 'time';

  factory SessionSetModel.fromJson(Map<String, dynamic> json) => SessionSetModel(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        exerciseName: json['exercise_name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        setNumber: json['set_number'] as int,
        reps: json['reps'] as int?,
        weightKg: json['weight_kg'] != null ? double.tryParse(json['weight_kg'].toString()) : null,
        durationSeconds: json['duration_seconds'] as int?,
        defaultReps: json['default_reps'] as int?,
        defaultWeightKg: json['default_weight_kg'] != null ? double.tryParse(json['default_weight_kg'].toString()) : null,
        defaultDurationSeconds: json['default_duration_seconds'] as int?,
        isSkipped: json['is_skipped'] as bool? ?? false,
        isCompleted: json['is_completed'] as bool? ?? false,
        restDurationSeconds: json['rest_duration_seconds'] as int? ?? 120,
        activityType: json['activity_type'] as String? ?? 'reps',
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
  final String sessionType; // gym | rest_day | cardio
  final int? cardioDurationSeconds;
  final double? cardioSpeed;
  final double? cardioIncline;
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
    this.sessionType = 'gym',
    this.cardioDurationSeconds,
    this.cardioSpeed,
    this.cardioIncline,
    required this.exercises,
  });

  bool get isActive => status == 'active';
  bool get isRestDay => sessionType == 'rest_day' || planName.toLowerCase() == 'rest day';
  bool get isCardio => sessionType == 'cardio';

  Duration? get duration {
    if (cardioDurationSeconds != null) {
      return Duration(seconds: cardioDurationSeconds!);
    }
    return completedAt?.difference(startedAt);
  }

  String? get formattedCardioDuration {
    if (cardioDurationSeconds == null) return null;
    final m = cardioDurationSeconds! ~/ 60;
    final s = cardioDurationSeconds! % 60;
    if (s == 0) return '$m min${m != 1 ? 's' : ''}';
    return '${m}m ${s}s';
  }

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
        sessionType: json['session_type'] as String? ?? 'gym',
        cardioDurationSeconds: json['cardio_duration_seconds'] as int?,
        cardioSpeed: json['cardio_speed'] != null ? double.tryParse(json['cardio_speed'].toString()) : null,
        cardioIncline: json['cardio_incline'] != null ? double.tryParse(json['cardio_incline'].toString()) : null,
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => ExerciseSessionModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
