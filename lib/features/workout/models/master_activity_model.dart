import 'dart:convert';

// =============================================================================
// ActivityMuscle — a single muscle entry (primary or secondary)
// =============================================================================

class ActivityMuscle {
  final String muscleName;
  final bool isPrimary;

  const ActivityMuscle({
    required this.muscleName,
    required this.isPrimary,
  });

  factory ActivityMuscle.fromJson(Map<String, dynamic> json) => ActivityMuscle(
        muscleName: json['muscle_name'] as String,
        isPrimary: json['is_primary'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'muscle_name': muscleName,
        'is_primary': isPrimary,
      };

  /// Display-friendly name, e.g. "lower back" → "Lower Back"
  String get displayName => muscleName
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// =============================================================================
// MasterActivityModel — a canonical gym exercise
// =============================================================================

class MasterActivityModel {
  final String id;
  final String name;

  /// High-level category: "Strength", "Stretching", "Cardio", etc.
  final String? category;

  /// Primary muscle (backward compat — same as primaryMuscles[0]).
  final String? muscleGroup;

  /// Activity type: 'reps' | 'time'
  final String activityType;

  // --- Enriched fields from free-exercise-db ---

  /// Equipment required, e.g. "barbell", "dumbbell", "body only"
  final String? equipment;

  /// Difficulty level: "beginner" | "intermediate" | "expert"
  final String? level;

  /// Movement direction: "push" | "pull" | "static"
  final String? force;

  /// Movement type: "compound" | "isolation"
  final String? mechanic;

  /// Full URL to start-position form image
  final String? imageUrl0;

  /// Full URL to end-position form image
  final String? imageUrl1;

  /// Step-by-step instructions
  final List<String> instructions;

  /// All muscle targets (primary + secondary), sorted primary-first
  final List<ActivityMuscle> muscles;

  const MasterActivityModel({
    required this.id,
    required this.name,
    this.category,
    this.muscleGroup,
    this.activityType = 'reps',
    this.equipment,
    this.level,
    this.force,
    this.mechanic,
    this.imageUrl0,
    this.imageUrl1,
    this.instructions = const [],
    this.muscles = const [],
  });

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  bool get isTimeBased => activityType == 'time';

  /// Primary muscles only
  List<ActivityMuscle> get primaryMuscles =>
      muscles.where((m) => m.isPrimary).toList();

  /// Secondary muscles only
  List<ActivityMuscle> get secondaryMuscles =>
      muscles.where((m) => !m.isPrimary).toList();

  /// First primary muscle, if available
  ActivityMuscle? get mainMuscle => muscles.isNotEmpty
      ? muscles.firstWhere((m) => m.isPrimary, orElse: () => muscles.first)
      : null;

  /// True if at least one form image is available
  bool get hasFormImage => imageUrl0 != null && imageUrl0!.isNotEmpty;

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  factory MasterActivityModel.fromJson(Map<String, dynamic> json) {
    // Parse instructions — stored as JSON string in DB
    List<String> instructions = [];
    final rawInstr = json['instructions'];
    if (rawInstr is String && rawInstr.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawInstr);
        if (decoded is List) {
          instructions = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        instructions = [];
      }
    } else if (rawInstr is List) {
      instructions = rawInstr.map((e) => e.toString()).toList();
    }

    // Parse muscles array
    final rawMuscles = json['muscles'];
    List<ActivityMuscle> muscles = [];
    if (rawMuscles is List) {
      muscles = rawMuscles
          .map((e) => ActivityMuscle.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return MasterActivityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      muscleGroup: json['muscle_group'] as String?,
      activityType: json['activity_type'] as String? ?? 'reps',
      equipment: json['equipment'] as String?,
      level: json['level'] as String?,
      force: json['force'] as String?,
      mechanic: json['mechanic'] as String?,
      imageUrl0: json['image_url_0'] as String?,
      imageUrl1: json['image_url_1'] as String?,
      instructions: instructions,
      muscles: muscles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'muscle_group': muscleGroup,
        'activity_type': activityType,
        'equipment': equipment,
        'level': level,
        'force': force,
        'mechanic': mechanic,
        'image_url_0': imageUrl0,
        'image_url_1': imageUrl1,
        'instructions': instructions,
        'muscles': muscles.map((m) => m.toJson()).toList(),
      };
}
