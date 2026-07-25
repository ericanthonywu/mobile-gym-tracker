class MealItemModel {
  final String mealSettingId;
  final String name;
  final int sortOrder;
  final String logDate;
  final bool isChecked;
  final String? logId;

  const MealItemModel({
    required this.mealSettingId,
    required this.name,
    required this.sortOrder,
    required this.logDate,
    required this.isChecked,
    this.logId,
  });

  factory MealItemModel.fromJson(Map<String, dynamic> json) => MealItemModel(
        mealSettingId: json['mealSettingId'] as String,
        name: json['name'] as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
        logDate: json['logDate'] as String,
        isChecked: json['isChecked'] as bool? ?? false,
        logId: json['logId'] as String?,
      );

  MealItemModel copyWith({bool? isChecked}) => MealItemModel(
        mealSettingId: mealSettingId,
        name: name,
        sortOrder: sortOrder,
        logDate: logDate,
        isChecked: isChecked ?? this.isChecked,
        logId: logId,
      );
}

class MealSettingModel {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  const MealSettingModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  factory MealSettingModel.fromJson(Map<String, dynamic> json) => MealSettingModel(
        id: json['id'] as String,
        name: json['name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class MealSummaryModel {
  final String range;
  final int mealsPerDay;
  final int totalPossible;
  final int totalChecked;
  final int totalSkipped;
  final int compliancePct;
  final List<MealDaySummary> byDate;

  const MealSummaryModel({
    required this.range,
    required this.mealsPerDay,
    required this.totalPossible,
    required this.totalChecked,
    required this.totalSkipped,
    required this.compliancePct,
    required this.byDate,
  });

  factory MealSummaryModel.fromJson(Map<String, dynamic> json) => MealSummaryModel(
        range: json['range'] as String? ?? 'weekly',
        mealsPerDay: json['mealsPerDay'] as int? ?? 3,
        totalPossible: json['totalPossible'] as int? ?? 0,
        totalChecked: json['totalChecked'] as int? ?? 0,
        totalSkipped: json['totalSkipped'] as int? ?? 0,
        compliancePct: json['compliancePct'] as int? ?? 0,
        byDate: (json['byDate'] as List<dynamic>? ?? [])
            .map((d) => MealDaySummary.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}

class MealDaySummary {
  final String date;
  final int checkedCount;
  final int totalCount;

  const MealDaySummary({required this.date, required this.checkedCount, required this.totalCount});

  factory MealDaySummary.fromJson(Map<String, dynamic> json) => MealDaySummary(
        date: json['date'] as String,
        checkedCount: json['checkedCount'] as int? ?? 0,
        totalCount: json['totalCount'] as int? ?? 0,
      );
}
