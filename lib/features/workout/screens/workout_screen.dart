import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/master_activity_model.dart';
import 'package:gym_tracker/features/workout/models/workout_plan_model.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/master_activity_provider.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:gym_tracker/features/workout/providers/workout_plans_provider.dart';
import 'package:gym_tracker/features/workout/screens/pre_session_editor_screen.dart';
import 'package:gym_tracker/features/workout/widgets/exercise_form_preview.dart';
import 'package:intl/intl.dart';

/// Format seconds as MM:SS for time-based exercise display.
String _fmtDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
  if (d.inMinutes > 0) {
    return '${d.inMinutes}m';
  }
  return '${d.inSeconds}s';
}

/// Main workout tab — 4 sub-sections: Plans, Schedule, History, Stats
class WorkoutScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const WorkoutScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Workout'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Plans'),
            Tab(text: 'Schedule'),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton(
              onPressed: () => context.push('/plan/new').then((_) => ref.invalidate(workoutPlansProvider)),
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: [
          _PlansTab(onChanged: () => ref.invalidate(workoutPlansProvider)),
          _ScheduleTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plans Tab
// ---------------------------------------------------------------------------
class _PlansTab extends ConsumerWidget {
  final VoidCallback? onChanged;
  const _PlansTab({this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(workoutPlansProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: () async {
        ref.invalidate(workoutPlansProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: plans.when(
        data: (data) {
          if (data.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fitness_center_outlined, color: AppColors.textDisabled, size: 56),
                        const SizedBox(height: 16),
                        Text('No plans yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Tap + to create your first workout plan!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(20),
            itemCount: data.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0) {
                return _QuickWorkoutBanner();
              }
              return _PlanCard(plan: data[i - 1], onChanged: onChanged);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text('Failed to load plans', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              TextButton(onPressed: () => ref.refresh(workoutPlansProvider), child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickWorkoutBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(
          '/session/pre-editor?quick=true&planName=Quick+Workout',
          extra: <ExerciseEntry>[],
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Quick Workout ⚡',
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Start an ad-hoc session without selecting a plan',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'START',
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textOnPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textOnPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  final WorkoutPlanModel plan;
  final VoidCallback? onChanged;
  const _PlanCard({required this.plan, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Plan header
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            title: Text(plan.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    )),
            subtitle: Text('${plan.exercises.length} exercise${plan.exercises.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                  onPressed: () => context.push('/plan/${plan.id}/edit').then((_) => onChanged?.call()),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
          // Exercises
          if (plan.exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: plan.exercises.map((e) {
                  // Look up full activity model for eye icon
                  final allActivities = ref.watch(masterActivitiesProvider).value ?? [];
                  final matched = allActivities
                      .cast<MasterActivityModel?>()
                      .firstWhere(
                        (a) => a!.name.toLowerCase() == e.name.toLowerCase(),
                        orElse: () => null,
                      );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.name, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
                        ),
                        Text(
                            e.isTimeBased
                                ? '${e.targetSets}×${_fmtDuration(e.targetDurationSeconds ?? 0)}'
                                : '${e.targetSets}×${e.targetReps}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                        if (matched != null && matched.hasFormImage) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => showExerciseFormPreview(context, matched),
                            child: const Icon(Icons.remove_red_eye_rounded, size: 14, color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          // Start button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _startSession(context, ref);
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('START THIS WORKOUT'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(activeSessionNotifierProvider.notifier).startSession(planId: plan.id);
      // Show live activity error if it failed (for diagnosis)
      final laError = ref.read(activeSessionNotifierProvider.notifier).liveActivityError;
      if (laError != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LiveActivity: $laError'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }
      if (context.mounted) context.push('/session/active');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractApiError(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }


  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Delete Plan?'),
        content: Text('Are you sure you want to delete "${plan.name}"? This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await ApiClient.instance.delete(ApiEndpoints.workoutPlanById(plan.id));
        ref.invalidate(workoutPlansProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(extractApiError(e)), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Schedule Tab
// ---------------------------------------------------------------------------
class _ScheduleTab extends ConsumerWidget {
  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(_scheduleProvider);

    return scheduleAsync.when(
      data: (schedule) => Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final day = schedule.firstWhere((d) => d['day_of_week'] == i, orElse: () => {'day_of_week': i});
                final planName = day['plan_name'] as String?;
                final isRest = day['is_rest_day'] as bool? ?? false;
                return _ScheduleDayRow(
                  dayIndex: i,
                  dayName: _dayNames[i],
                  planName: planName,
                  isRestDay: isRest,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/schedule/edit').then((_) => ref.invalidate(_scheduleProvider)),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('EDIT SCHEDULE'),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(child: Text('Failed to load schedule')),
    );
  }
}

final _scheduleProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient.instance.get(ApiEndpoints.schedule);
  return List<Map<String, dynamic>>.from(response.data['data'] as List);
});

class _ScheduleDayRow extends StatelessWidget {
  final int dayIndex;
  final String dayName;
  final String? planName;
  final bool isRestDay;

  const _ScheduleDayRow({
    required this.dayIndex,
    required this.dayName,
    required this.planName,
    required this.isRestDay,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // 0=Mon…6=Sun; weekday 1=Mon
    final isToday = ((today.weekday - 1) % 7) == dayIndex;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isToday ? AppColors.primaryMuted : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isToday ? AppColors.primary.withOpacity(0.4) : AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              dayName.substring(0, 3).toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isToday ? AppColors.primary : AppColors.textSecondary,
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isRestDay ? 'Rest Day 😴' : (planName ?? 'No plan assigned'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isRestDay ? AppColors.textSecondary : AppColors.textPrimary,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
              child: const Text('TODAY', style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textOnPrimary)),
            ),
        ],
      ),
    );
  }
}

