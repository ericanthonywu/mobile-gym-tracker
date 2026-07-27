class MenstruationLogModel {
  final String id;
  final DateTime startDate;
  final DateTime? endDate;
  final String? flowIntensity;
  final String? notes;

  MenstruationLogModel({
    required this.id,
    required this.startDate,
    this.endDate,
    this.flowIntensity,
    this.notes,
  });

  factory MenstruationLogModel.fromJson(Map<String, dynamic> json) {
    return MenstruationLogModel(
      id: json['id'] as String,
      startDate: DateTime.parse(json['start_date'] as String).toLocal(),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String).toLocal() : null,
      flowIntensity: json['flow_intensity'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
      'flow_intensity': flowIntensity,
      'notes': notes,
    };
  }
}
