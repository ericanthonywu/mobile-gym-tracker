import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/master_activity_model.dart';
import 'package:gym_tracker/features/workout/models/workout_plan_model.dart';
import 'package:gym_tracker/features/workout/providers/master_activity_provider.dart';
import 'package:gym_tracker/features/workout/providers/workout_plans_provider.dart';

/// Create or edit a workout plan — name + exercises (free text, sets, reps, drag-to-reorder).
class PlanEditorScreen extends ConsumerStatefulWidget {
  final String? planId;
  const PlanEditorScreen({super.key, this.planId});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _ExerciseEntry {
  String name;
  String activityType; // 'reps' | 'time'
  final TextEditingController setsCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController durationCtrl; // used when activityType == 'time'

  _ExerciseEntry({String name = '', int sets = 4, int reps = 12, String activityType = 'reps', int? durationSeconds})
      : name = name,
        activityType = activityType,
        setsCtrl = TextEditingController(text: sets.toString()),
        repsCtrl = TextEditingController(text: reps > 0 ? reps.toString() : '12'),
        durationCtrl = TextEditingController(text: durationSeconds != null ? durationSeconds.toString() : '60');

  bool get isTimeBased => activityType == 'time';

  void dispose() {
    setsCtrl.dispose();
    repsCtrl.dispose();
    durationCtrl.dispose();
  }
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final _planNameCtrl = TextEditingController();
  final List<_ExerciseEntry> _exercises = [];
  bool _loading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.planId != null) {
      _isEditing = true;
      _loadPlan();
    } else {
      _exercises.add(_ExerciseEntry());
    }
  }

  Future<void> _loadPlan() async {
    setState(() => _loading = true);
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.workoutPlanById(widget.planId!));
      final plan = WorkoutPlanModel.fromJson(response.data as Map<String, dynamic>);
      _planNameCtrl.text = plan.name;
      _exercises.clear();
      for (final e in plan.exercises) {
        _exercises.add(_ExerciseEntry(
          name: e.name,
          sets: e.targetSets,
          reps: e.targetReps > 0 ? e.targetReps : 12,
          activityType: e.activityType,
          durationSeconds: e.targetDurationSeconds,
        ));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _planNameCtrl.dispose();
    for (final e in _exercises) { e.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_planNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your plan a name first!')),
      );
      return;
    }

    final exercises = _exercises.map((e) {
      if (e.isTimeBased) {
        return {
          'name': e.name.trim().isEmpty ? 'Exercise' : e.name.trim(),
          'targetSets': int.tryParse(e.setsCtrl.text) ?? 4,
          'targetReps': 0,
          'activityType': 'time',
          'targetDurationSeconds': int.tryParse(e.durationCtrl.text) ?? 60,
        };
      }
      return {
        'name': e.name.trim().isEmpty ? 'Exercise' : e.name.trim(),
        'targetSets': int.tryParse(e.setsCtrl.text) ?? 4,
        'targetReps': int.tryParse(e.repsCtrl.text) ?? 12,
        'activityType': 'reps',
      };
    }).toList();

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise!')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final payload = {'name': _planNameCtrl.text.trim(), 'exercises': exercises};

      if (_isEditing) {
        await ApiClient.instance.put(ApiEndpoints.workoutPlanById(widget.planId!), data: payload);
      } else {
        await ApiClient.instance.post(ApiEndpoints.workoutPlans, data: payload);
      }

      ref.invalidate(workoutPlansProvider);
      if (mounted) {
        HapticFeedback.mediumImpact();
        context.pop();
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save plan. Try again!'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_isEditing ? 'Edit Plan' : 'New Plan'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: _loading && _isEditing
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Plan name
                      TextField(
                        controller: _planNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Plan Name',
                          hintText: 'e.g. Leg Day, Push Day...',
                        ),
                        style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 20, fontWeight: FontWeight.w600),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Text('Exercises', style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          Text('Drag to reorder', style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Exercise list (reorderable)
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _exercises.removeAt(oldIndex);
                          _exercises.insert(newIndex, item);
                          setState(() {});
                        },
                        children: _exercises.asMap().entries.map((entry) {
                          return _ExerciseRow(
                            key: ValueKey(entry.key),
                            entry: entry.value,
                            onDelete: () => setState(() => _exercises.removeAt(entry.key)),
                            onChanged: () => setState(() {}),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _exercises.add(_ExerciseEntry()));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('ADD EXERCISE'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ExerciseRow extends StatefulWidget {
  final _ExerciseEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  const _ExerciseRow({super.key, required this.entry, required this.onDelete, required this.onChanged});

  @override
  State<_ExerciseRow> createState() => _ExerciseRowState();
}

class _ExerciseRowState extends State<_ExerciseRow> {
  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.drag_handle_rounded, color: AppColors.textDisabled, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: ActivitySearchDropdown(
                  initialName: entry.name,
                  onSelected: (name) {
                    entry.name = name;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDelete,
                child: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Activity type toggle — Reps / Time
          Row(
            children: [
              const SizedBox(width: 32),
              _TypeChip(
                label: 'Reps',
                icon: Icons.repeat_rounded,
                selected: !entry.isTimeBased,
                onTap: () => setState(() {
                  entry.activityType = 'reps';
                  widget.onChanged();
                }),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: 'Time',
                icon: Icons.timer_outlined,
                selected: entry.isTimeBased,
                onTap: () => setState(() {
                  entry.activityType = 'time';
                  widget.onChanged();
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: _NumberField(ctrl: entry.setsCtrl, label: 'Sets'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('×', style: const TextStyle(color: AppColors.textSecondary)),
              ),
              Expanded(
                child: entry.isTimeBased
                    ? _NumberField(ctrl: entry.durationCtrl, label: 'Duration (sec)')
                    : _NumberField(ctrl: entry.repsCtrl, label: 'Target Reps'),
              ),
              const SizedBox(width: 28),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _NumberField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            fillColor: AppColors.surfaceVariant,
            filled: true,
          ),
          style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 16, fontWeight: FontWeight.w600),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Searchable Activity Dropdown — backed by master_activities
// ---------------------------------------------------------------------------
class ActivitySearchDropdown extends ConsumerStatefulWidget {
  final String initialName;
  final ValueChanged<String> onSelected;
  const ActivitySearchDropdown({super.key, required this.initialName, required this.onSelected});

  @override
  ConsumerState<ActivitySearchDropdown> createState() => _ActivitySearchDropdownState();
}

class _ActivitySearchDropdownState extends ConsumerState<ActivitySearchDropdown> {
  late final TextEditingController _ctrl;
  bool _showDropdown = false;
  List<MasterActivityModel> _filtered = [];
  List<MasterActivityModel> _allActivities = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() {
      _showDropdown = q.isNotEmpty;
      _filtered = _allActivities
          .where((a) => a.name.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  Future<void> _selectOrCreate(String name) async {
    setState(() => _showDropdown = false);
    _ctrl.text = name;
    widget.onSelected(name);
    // Ensure master activity exists
    try {
      await findOrCreateActivity(name);
      ref.invalidate(masterActivitiesProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(masterActivitiesProvider).whenData((list) => _allActivities = list);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: _onSearch,
          decoration: const InputDecoration(
            hintText: 'Search or add exercise...',
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            prefixIcon: Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.textDisabled),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
          textCapitalization: TextCapitalization.words,
        ),
        if (_showDropdown)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                ..._filtered.map((a) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history_rounded, size: 14, color: AppColors.textSecondary),
                      title: Text(a.name, style: Theme.of(context).textTheme.bodyMedium),
                      subtitle: a.muscleGroup != null
                          ? Text(a.muscleGroup!, style: Theme.of(context).textTheme.labelSmall)
                          : null,
                      onTap: () => _selectOrCreate(a.name),
                    )),
                if (_ctrl.text.isNotEmpty &&
                    !_filtered.any((a) => a.name.toLowerCase() == _ctrl.text.toLowerCase()))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppColors.primary),
                    title: Text('Create \'${_ctrl.text}\'',
                        style: TextStyle(
                            color: AppColors.primary, fontWeight: FontWeight.w600)),
                    onTap: () => _selectOrCreate(_ctrl.text),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Type toggle chip (Reps / Time)
// ---------------------------------------------------------------------------
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
