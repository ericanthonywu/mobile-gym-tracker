/// Comparison result after recording a set vs the previous session.
class SetComparisonModel {
  final int prevReps;
  final double prevWeightKg;
  final int repsChange;
  final double weightChange;
  final String verdict; // 'improved' | 'same' | 'declined'

  const SetComparisonModel({
    required this.prevReps,
    required this.prevWeightKg,
    required this.repsChange,
    required this.weightChange,
    required this.verdict,
  });

  bool get isImproved => verdict == 'improved';
  bool get isSame => verdict == 'same';
  bool get isDeclined => verdict == 'declined';

  factory SetComparisonModel.fromJson(Map<String, dynamic> json) => SetComparisonModel(
        prevReps: json['prevReps'] as int? ?? 0,
        prevWeightKg: (json['prevWeightKg'] as num?)?.toDouble() ?? 0.0,
        repsChange: json['repsChange'] as int? ?? 0,
        weightChange: (json['weightChange'] as num?)?.toDouble() ?? 0.0,
        verdict: json['verdict'] as String? ?? 'same',
      );
}
