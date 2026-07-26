class MasterActivityModel {
  final String id;
  final String name;
  final String? category;
  final String? muscleGroup;
  final String activityType; // 'reps' | 'time'

  const MasterActivityModel({
    required this.id,
    required this.name,
    this.category,
    this.muscleGroup,
    this.activityType = 'reps',
  });

  bool get isTimeBased => activityType == 'time';

  factory MasterActivityModel.fromJson(Map<String, dynamic> json) => MasterActivityModel(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        muscleGroup: json['muscle_group'] as String?,
        activityType: json['activity_type'] as String? ?? 'reps',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'muscle_group': muscleGroup,
        'activity_type': activityType,
      };
}
