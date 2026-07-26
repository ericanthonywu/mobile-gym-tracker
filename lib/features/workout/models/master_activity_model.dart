class MasterActivityModel {
  final String id;
  final String name;
  final String? category;
  final String? muscleGroup;

  const MasterActivityModel({
    required this.id,
    required this.name,
    this.category,
    this.muscleGroup,
  });

  factory MasterActivityModel.fromJson(Map<String, dynamic> json) => MasterActivityModel(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        muscleGroup: json['muscle_group'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'muscle_group': muscleGroup,
      };
}
