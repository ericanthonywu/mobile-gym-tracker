import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/master_activity_model.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/master_activity_provider.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:gym_tracker/features/workout/widgets/exercise_form_preview.dart';

// ---------------------------------------------------------------------------
// Data class for an editable exercise entry in the pre-session editor
// ---------------------------------------------------------------------------
class _ExerciseEntry {
  String name;
  int targetSets;
  int targetReps;
  String activityType; // 'reps' | 'time'
  int? targetDurationSeconds;

  _ExerciseEntry({
    required this.name,
    this.targetSets = 3,
    this.targetReps = 12,
    this.activityType = 'reps',
    this.targetDurationSeconds,
  });

  bool get isTimeBased => activityType == 'time';

  Map<String, dynamic> toJson() => {
        'name': name,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'activityType': activityType,
        if (targetDurationSeconds != null) 'targetDurationSeconds': targetDurationSeconds,
      };
}

// ---------------------------------------------------------------------------
// Pre-Session Editor Screen
// ---------------------------------------------------------------------------

/// Shown after the user taps "Start Workout" (or "Quick Workout").
/// Lets them review and modify the plan's exercises before the session starts.
///
/// Parameters:
/// - [planId]: optional — if from a scheduled plan
/// - [planName]: display name for the session
/// - [initialExercises]: pre-populated exercises (from plan or last session)
/// - [isQuickWorkout]: true = started without a plan (free-form)
class PreSessionEditorScreen extends ConsumerStatefulWidget {
  final String? planId;
  final String planName;
  final List<_ExerciseEntry> initialExercises;
  final bool isQuickWorkout;

  const PreSessionEditorScreen({
    super.key,
    this.planId,
    required this.planName,
    required this.initialExercises,
    this.isQuickWorkout = false,
  });

  @override
  ConsumerState<PreSessionEditorScreen> createState() => _PreSessionEditorScreenState();
}

class _PreSessionEditorScreenState extends ConsumerState<PreSessionEditorScreen> {
  late List<_ExerciseEntry> _exercises;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.initialExercises);
  }

  Future<void> _startSession() async {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise to start!')),
      );
      return;
    }

    setState(() => _isStarting = true);
    try {
      HapticFeedback.mediumImpact();
      await ref.read(activeSessionNotifierProvider.notifier).startSession(
        planId: widget.planId,
        planName: widget.planName,
        exercises: _exercises.map((e) => e.toJson()).toList(),
      );
      if (mounted) {
        context.pushReplacement('/session/active');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: $e')),
        );
      }
    }
  }

  void _addExercise(_ExerciseEntry entry) {
    setState(() => _exercises.add(entry));
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
  }

  void _editExercise(int index) async {
    final entry = _exercises[index];
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExerciseEditSheet(
        entry: entry,
        onSave: (updated) {
          setState(() => _exercises[index] = updated);
        },
      ),
    );
  }

  void _showAddExerciseSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddExerciseSheet(
        onAdd: _addExercise,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isQuickWorkout ? 'Quick Workout' : 'Review & Modify',
              style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            Text(
              widget.planName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _showAddExerciseSheet,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('ADD', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Hint bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: AppColors.primaryMuted,
            child: Row(
              children: [
                const Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Drag to reorder  ·  Tap to edit sets/reps  ·  Swipe to remove',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Exercise list (reorderable)
          Expanded(
            child: _exercises.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center_outlined,
                            size: 56, color: AppColors.textDisabled.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No exercises yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Tap ADD to build your workout',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showAddExerciseSheet,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('ADD EXERCISE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _exercises.length,
                    onReorder: _reorderExercises,
                    itemBuilder: (context, index) {
                      final entry = _exercises[index];
                      return _ExerciseEntryTile(
                        key: ValueKey('$index-${entry.name}'),
                        entry: entry,
                        index: index,
                        onEdit: () => _editExercise(index),
                        onRemove: () => _removeExercise(index),
                      );
                    },
                  ),
          ),
        ],
      ),

      // Start Button fixed at bottom
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_exercises.isNotEmpty)
                Text(
                  '${_exercises.length} exercise${_exercises.length != 1 ? 's' : ''} · ${_exercises.fold(0, (s, e) => s + e.targetSets)} total sets',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isStarting ? null : _startSession,
                  icon: _isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(_isStarting ? 'STARTING...' : 'START WORKOUT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise Entry Tile (in the reorderable list)
// ---------------------------------------------------------------------------
class _ExerciseEntryTile extends StatelessWidget {
  final _ExerciseEntry entry;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ExerciseEntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final setLabel = entry.isTimeBased
        ? '${entry.targetSets} sets · ${(entry.targetDurationSeconds ?? 60) ~/ 60}:${((entry.targetDurationSeconds ?? 60) % 60).toString().padLeft(2, '0')} each'
        : '${entry.targetSets} × ${entry.targetReps}';

    return Dismissible(
      key: ValueKey('dismiss-${index}-${entry.name}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 26),
      ),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Drag handle
              const Icon(Icons.drag_indicator_rounded, color: AppColors.textDisabled, size: 22),
              const SizedBox(width: 10),

              // Exercise number badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Exercise name + sets
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      setLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

              // Edit icon
              const Icon(Icons.edit_outlined, color: AppColors.textDisabled, size: 18),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Exercise Sheet (edit sets/reps for an existing entry)
// ---------------------------------------------------------------------------
class _ExerciseEditSheet extends StatefulWidget {
  final _ExerciseEntry entry;
  final void Function(_ExerciseEntry) onSave;

  const _ExerciseEditSheet({required this.entry, required this.onSave});

  @override
  State<_ExerciseEditSheet> createState() => _ExerciseEditSheetState();
}

class _ExerciseEditSheetState extends State<_ExerciseEditSheet> {
  late int _sets;
  late int _reps;
  late String _activityType;
  late int _durationSeconds;

  @override
  void initState() {
    super.initState();
    _sets = widget.entry.targetSets;
    _reps = widget.entry.targetReps;
    _activityType = widget.entry.activityType;
    _durationSeconds = widget.entry.targetDurationSeconds ?? 60;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            widget.entry.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),

          // Activity type toggle
          Row(
            children: [
              Text('Type:', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              _TypeToggle(
                selected: _activityType == 'reps',
                label: 'Reps',
                onTap: () => setState(() => _activityType = 'reps'),
              ),
              const SizedBox(width: 8),
              _TypeToggle(
                selected: _activityType == 'time',
                label: 'Time',
                onTap: () => setState(() => _activityType = 'time'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sets stepper
          _StepperRow(
            label: 'Sets',
            value: _sets,
            min: 1,
            max: 20,
            onChanged: (v) => setState(() => _sets = v),
          ),
          const SizedBox(height: 16),

          if (_activityType == 'reps') ...[
            _StepperRow(
              label: 'Reps',
              value: _reps,
              min: 1,
              max: 100,
              onChanged: (v) => setState(() => _reps = v),
            ),
          ] else ...[
            _StepperRow(
              label: 'Duration (sec)',
              value: _durationSeconds,
              min: 5,
              max: 3600,
              step: 5,
              onChanged: (v) => setState(() => _durationSeconds = v),
              suffix: '${_durationSeconds ~/ 60}:${(_durationSeconds % 60).toString().padLeft(2, '0')}',
            ),
          ],
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(_ExerciseEntry(
                  name: widget.entry.name,
                  targetSets: _sets,
                  targetReps: _reps,
                  activityType: _activityType,
                  targetDurationSeconds: _activityType == 'time' ? _durationSeconds : null,
                ));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('SAVE', style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _TypeToggle({required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final void Function(int) onChanged;
  final String? suffix;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        IconButton(
          onPressed: value > min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: AppColors.primary,
          disabledColor: AppColors.textDisabled,
        ),
        Container(
          width: 56,
          alignment: Alignment.center,
          child: Text(
            suffix ?? '$value',
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: AppColors.primary,
          disabledColor: AppColors.textDisabled,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add Exercise Sheet (search + create)
// ---------------------------------------------------------------------------
class _AddExerciseSheet extends ConsumerStatefulWidget {
  final void Function(_ExerciseEntry) onAdd;

  const _AddExerciseSheet({required this.onAdd});

  @override
  ConsumerState<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<_AddExerciseSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedMuscle;   // null = no filter
  String? _selectedCategory; // null = no filter
  String _activityType = 'reps';
  int _sets = 3;
  int _reps = 12;
  int _durationSeconds = 60;
  String? _selectedName;
  MasterActivityModel? _selectedActivity; // full model for eye preview

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muscles = ref.watch(activityMusclesProvider);
    final categories = ref.watch(activityCategoriesProvider);
    final searchResults = ref.watch(
      activitySearchProvider((
        query: _query,
        muscle: _selectedMuscle,
        category: _selectedCategory,
      )),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add Exercise',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'BarlowCondensed',
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                // Search field
                TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search or type new exercise name…',
                    hintStyle: const TextStyle(color: AppColors.textDisabled),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 8),
                // ── Category filter chips ──
                categories.when(
                  data: (list) {
                    if (list.isEmpty) return const SizedBox.shrink();
                    final options = list.map((c) => c['category'] as String).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CATEGORY',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textDisabled, letterSpacing: 1.4),
                        ),
                        const SizedBox(height: 4),
                        _MuscleFilterDropdown(
                          selected: _selectedCategory,
                          muscles: options,
                          onChanged: (c) => setState(() => _selectedCategory = c),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'MUSCLE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textDisabled, letterSpacing: 1.4),
                        ),
                        const SizedBox(height: 4),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                // ── Muscle filter chips ──
                muscles.when(
                  data: (list) {
                    final options = list.map((m) => m['muscle_name'] as String).toList();
                    return _MuscleFilterDropdown(
                      selected: _selectedMuscle,
                      muscles: options,
                      onChanged: (m) => setState(() => _selectedMuscle = m),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // If a name is typed/selected, show the config panel
          if (_selectedName != null) ...[
            _buildConfigPanel(context),
          ] else ...[
            // Results list
            Expanded(
              child: searchResults.when(
                data: (activities) {
                  final items = activities;
                  // Show "Add as new" option if query doesn't match any result exactly
                  final queryLower = _query.toLowerCase();
                  final hasExactMatch = items.any((a) => a.name.toLowerCase() == queryLower);

                  return ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      if (_query.isNotEmpty && !hasExactMatch)
                        _SearchResultTile(
                          name: _query,
                          isNew: true,
                          onTap: () => setState(() => _selectedName = _query),
                        ),
                      ...items.map(
                        (a) => _SearchResultTile(
                          name: a.name,
                          muscleGroup: a.muscleGroup,
                          activityType: a.activityType,
                          activity: a,
                          onTap: () => setState(() {
                            _selectedName = a.name;
                            _activityType = a.activityType;
                            _selectedActivity = a;
                          }),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (_, __) => const Center(child: Text('Failed to load exercises', style: TextStyle(color: AppColors.textSecondary))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigPanel(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected exercise name chip + eye icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedName!,
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  // Eye icon — show if we have a form image for this exercise
                  if (_selectedActivity != null && _selectedActivity!.hasFormImage)
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye_rounded, size: 20, color: AppColors.primary),
                      tooltip: 'View form',
                      onPressed: () => showExerciseFormPreview(context, _selectedActivity!),
                      padding: const EdgeInsets.only(left: 8),
                      constraints: const BoxConstraints(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                    onPressed: () => setState(() {
                      _selectedName = null;
                      _selectedActivity = null;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Type toggle
            Row(
              children: [
                Text('Type:', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                _TypeToggle(
                  selected: _activityType == 'reps',
                  label: 'Reps',
                  onTap: () => setState(() => _activityType = 'reps'),
                ),
                const SizedBox(width: 8),
                _TypeToggle(
                  selected: _activityType == 'time',
                  label: 'Time',
                  onTap: () => setState(() => _activityType = 'time'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _StepperRow(
              label: 'Sets',
              value: _sets,
              min: 1,
              max: 20,
              onChanged: (v) => setState(() => _sets = v),
            ),
            const SizedBox(height: 16),

            if (_activityType == 'reps')
              _StepperRow(
                label: 'Reps',
                value: _reps,
                min: 1,
                max: 100,
                onChanged: (v) => setState(() => _reps = v),
              )
            else
              _StepperRow(
                label: 'Duration (sec)',
                value: _durationSeconds,
                min: 5,
                max: 3600,
                step: 5,
                onChanged: (v) => setState(() => _durationSeconds = v),
                suffix: '${_durationSeconds ~/ 60}:${(_durationSeconds % 60).toString().padLeft(2, '0')}',
              ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onAdd(_ExerciseEntry(
                    name: _selectedName!,
                    targetSets: _sets,
                    targetReps: _activityType == 'reps' ? _reps : 0,
                    activityType: _activityType,
                    targetDurationSeconds: _activityType == 'time' ? _durationSeconds : null,
                  ));
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('ADD TO WORKOUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final String name;
  final String? muscleGroup;
  final String? activityType;
  final bool isNew;
  final VoidCallback onTap;
  final MasterActivityModel? activity;

  const _SearchResultTile({
    required this.name,
    this.muscleGroup,
    this.activityType,
    this.isNew = false,
    required this.onTap,
    this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreview = activity != null && activity!.hasFormImage;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isNew ? AppColors.primaryMuted : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNew ? AppColors.primary.withOpacity(0.3) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isNew ? Icons.add_circle_outline_rounded : Icons.fitness_center_rounded,
              size: 18,
              color: isNew ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNew ? 'Add "$name" as new exercise' : name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isNew ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  if (muscleGroup != null)
                    Text(
                      muscleGroup!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
                    ),
                ],
              ),
            ),
            if (activityType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activityType!,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            if (hasPreview) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => showExerciseFormPreview(context, activity!),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Icon(
                    Icons.remove_red_eye_rounded,
                    size: 18,
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expose _ExerciseEntry for use in other files
// ---------------------------------------------------------------------------
class ExerciseEntry extends _ExerciseEntry {
  ExerciseEntry({
    required super.name,
    super.targetSets,
    super.targetReps,
    super.activityType,
    super.targetDurationSeconds,
  });

  static ExerciseEntry fromSessionExercise(ExerciseSessionModel ex) {
    final firstSet = ex.sets.isNotEmpty ? ex.sets.first : null;
    return ExerciseEntry(
      name: ex.exerciseName,
      targetSets: ex.totalSets,
      targetReps: firstSet?.defaultReps ?? firstSet?.reps ?? 12,
      activityType: firstSet?.activityType ?? 'reps',
      targetDurationSeconds: firstSet?.defaultDurationSeconds,
    );
  }

  static ExerciseEntry fromPlanExercise(Map<String, dynamic> ex) {
    return ExerciseEntry(
      name: ex['name'] as String,
      targetSets: (ex['target_sets'] as int?) ?? 3,
      targetReps: (ex['target_reps'] as int?) ?? 12,
      activityType: ex['activity_type'] as String? ?? 'reps',
      targetDurationSeconds: ex['target_duration_seconds'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// Muscle filter dropdown — horizontally scrollable pill chips
// ---------------------------------------------------------------------------
class _MuscleFilterDropdown extends StatelessWidget {
  final String? selected;
  final List<String> muscles;
  final ValueChanged<String?> onChanged;

  const _MuscleFilterDropdown({
    required this.selected,
    required this.muscles,
    required this.onChanged,
  });

  String _capitalize(String s) => s.isEmpty
      ? s
      : s.split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" chip
          _MuscleChip(
            label: 'All Muscles',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 6),
          ...muscles.map((m) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _MuscleChip(
                  label: _capitalize(m),
                  selected: selected == m,
                  onTap: () => onChanged(selected == m ? null : m),
                ),
              )),
        ],
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MuscleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
