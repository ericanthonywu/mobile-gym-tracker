/// Comparison result after recording a set vs the previous session.
class SetComparisonModel {
  final bool isTimeBased;

  // Reps-based fields
  final int prevReps;
  final double prevWeightKg;
  final int repsChange;
  final double weightChange;

  // Time-based fields
  final int prevDurationSeconds;
  final int durationChange;
  final int? topRecordSeconds;
  final bool isNewTopRecord;

  final String verdict; // 'improved' | 'same' | 'declined'

  const SetComparisonModel({
    this.isTimeBased = false,
    this.prevReps = 0,
    this.prevWeightKg = 0.0,
    this.repsChange = 0,
    this.weightChange = 0.0,
    this.prevDurationSeconds = 0,
    this.durationChange = 0,
    this.topRecordSeconds,
    this.isNewTopRecord = false,
    required this.verdict,
  });

  bool get isImproved => verdict == 'improved';
  bool get isSame => verdict == 'same';
  bool get isDeclined => verdict == 'declined';

  factory SetComparisonModel.fromJson(Map<String, dynamic> json) {
    final timeBased = json['isTimeBased'] as bool? ?? false;
    if (timeBased) {
      return SetComparisonModel(
        isTimeBased: true,
        prevDurationSeconds: json['prevDurationSeconds'] as int? ?? 0,
        durationChange: json['durationChange'] as int? ?? 0,
        topRecordSeconds: json['topRecordSeconds'] as int?,
        isNewTopRecord: json['isNewTopRecord'] as bool? ?? false,
        verdict: json['verdict'] as String? ?? 'same',
      );
    }
    return SetComparisonModel(
      isTimeBased: false,
      prevReps: json['prevReps'] as int? ?? 0,
      prevWeightKg: (json['prevWeightKg'] as num?)?.toDouble() ?? 0.0,
      repsChange: json['repsChange'] as int? ?? 0,
      weightChange: (json['weightChange'] as num?)?.toDouble() ?? 0.0,
      verdict: json['verdict'] as String? ?? 'same',
    );
  }
}

