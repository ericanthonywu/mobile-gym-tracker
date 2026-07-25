class ExerciseModel {
  final String id;
  final String planId;
  final String name;
  final int targetSets;
  final int targetReps;
  final int sortOrder;

  const ExerciseModel({
    required this.id,
    required this.planId,
    required this.name,
    required this.targetSets,
    required this.targetReps,
    required this.sortOrder,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) => ExerciseModel(
        id: json['id'] as String,
        planId: json['plan_id'] as String? ?? '',
        name: json['name'] as String,
        targetSets: json['target_sets'] as int? ?? 4,
        targetReps: json['target_reps'] as int? ?? 12,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class WorkoutPlanModel {
  final String id;
  final String name;
  final List<ExerciseModel> exercises;
  final DateTime createdAt;

  const WorkoutPlanModel({
    required this.id,
    required this.name,
    required this.exercises,
    required this.createdAt,
  });

  factory WorkoutPlanModel.fromJson(Map<String, dynamic> json) => WorkoutPlanModel(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
