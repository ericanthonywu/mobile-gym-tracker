class WeightLogModel {
  final String id;
  final double weightKg;
  final DateTime loggedAt;
  final String? notes;

  const WeightLogModel({
    required this.id,
    required this.weightKg,
    required this.loggedAt,
    this.notes,
  });

  factory WeightLogModel.fromJson(Map<String, dynamic> json) => WeightLogModel(
        id: json['id'] as String,
        weightKg: double.tryParse(json['weight_kg'].toString()) ?? 0,
        loggedAt: DateTime.tryParse(json['logged_at'] as String? ?? '') ?? DateTime.now(),
        notes: json['notes'] as String?,
      );
}

class WeightChartPoint {
  final String date;
  final double weightKg;
  const WeightChartPoint({required this.date, required this.weightKg});

  factory WeightChartPoint.fromJson(Map<String, dynamic> json) => WeightChartPoint(
        date: json['date'] as String,
        weightKg: double.tryParse(json['weightKg'].toString()) ?? 0,
      );
}

class WeightSummaryModel {
  final double? minKg;
  final double? maxKg;
  final double? avgKg;
  final int entryCount;
  final String trend; // up | down | stable

  const WeightSummaryModel({
    this.minKg,
    this.maxKg,
    this.avgKg,
    required this.entryCount,
    required this.trend,
  });

  factory WeightSummaryModel.fromJson(Map<String, dynamic> json) => WeightSummaryModel(
        minKg: json['minKg'] != null ? double.tryParse(json['minKg'].toString()) : null,
        maxKg: json['maxKg'] != null ? double.tryParse(json['maxKg'].toString()) : null,
        avgKg: json['avgKg'] != null ? double.tryParse(json['avgKg'].toString()) : null,
        entryCount: json['entryCount'] as int? ?? 0,
        trend: json['trend'] as String? ?? 'stable',
      );
}
