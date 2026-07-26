import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/workout_plan_model.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:gym_tracker/features/workout/providers/workout_plans_provider.dart';
import 'package:gym_tracker/features/workout/screens/exercise_stats_screen.dart';
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
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
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
            Tab(text: 'History'),
            Tab(text: 'Stats'),
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
          const _HistoryTab(),
          const ExerciseStatsScreen(),
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
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _PlanCard(plan: data[i], onChanged: onChanged),
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

// ---------------------------------------------------------------------------
// History Tab
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// History Tab
// ---------------------------------------------------------------------------
class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  bool _isCalendarMode = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    final monthFormat = DateFormat('MMMM yyyy');
    final isCurrentMonth = _focusedMonth.year == DateTime.now().year && _focusedMonth.month == DateTime.now().month;

    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
            });
          },
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
          tooltip: 'Previous month',
        ),
        Expanded(
          child: Center(
            child: Text(
              monthFormat.format(_focusedMonth),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
            ),
          ),
        ),
        if (!isCurrentMonth)
          TextButton(
            onPressed: () {
              setState(() {
                final now = DateTime.now();
                _focusedMonth = DateTime(now.year, now.month, 1);
                _selectedDate = DateTime(now.year, now.month, now.day);
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('TODAY', style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
            });
          },
          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
          tooltip: 'Next month',
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(List<WorkoutSessionModel> sessions) {
    const weekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7; // Monday-first
    final totalGridCells = startOffset + daysInMonth;
    final totalRows = ((totalGridCells + 6) / 7).floor();
    final totalCells = totalRows * 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Weekday Labels Header
          Row(
            children: weekDays
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
              final daySessions = sessions.where((s) => _isSameDay(s.completedAt ?? s.startedAt, cellDate)).toList();
              final hasActivity = daySessions.isNotEmpty;
              final hasGym = daySessions.any((s) => !s.isRestDay && !s.isCardio);
              final hasRestDay = daySessions.any((s) => s.isRestDay);
              final hasCardio = daySessions.any((s) => s.isCardio);
              final hasMakeUp = daySessions.any((s) => s.wasMakeUpSession);
              final isToday = _isSameDay(DateTime.now(), cellDate);
              final isSelected = _isSameDay(_selectedDate, cellDate);

              IconData flagIcon = Icons.flag_rounded;
              Color flagColor = AppColors.primary;
              if (hasGym) {
                flagIcon = Icons.flag_rounded;
                flagColor = hasMakeUp ? AppColors.warning : AppColors.primary;
              } else if (hasRestDay) {
                flagIcon = Icons.bed_rounded;
                flagColor = AppColors.info;
              } else if (hasCardio) {
                flagIcon = Icons.directions_run_rounded;
                flagColor = AppColors.warning;
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryMuted
                        : (isToday ? AppColors.surfaceVariant : AppColors.background),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.5)),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontFamily: 'Barlow',
                          fontWeight: isSelected || isToday || hasActivity ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                          color: isSelected
                              ? AppColors.primary
                              : (isToday ? AppColors.textPrimary : (hasActivity ? AppColors.textPrimary : AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (hasActivity)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: flagColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                flagIcon,
                                size: 10,
                                color: flagColor,
                              ),
                              if (daySessions.length > 1) ...[
                                const SizedBox(width: 1),
                                Text(
                                  '${daySessions.length}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: flagColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsForSelectedDate(List<WorkoutSessionModel> sessions) {
    final selectedSessions = sessions.where((s) => _isSameDay(s.completedAt ?? s.startedAt, _selectedDate)).toList();

    if (selectedSessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_available_outlined, color: AppColors.textDisabled, size: 40),
            const SizedBox(height: 10),
            Text(
              'No workout on ${DateFormat('MMM d, y').format(_selectedDate)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap any date with a flag 🚩 on the calendar to view history',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: selectedSessions.map((session) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SessionHistoryCard(session: session),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded, color: AppColors.textDisabled, size: 56),
            const SizedBox(height: 16),
            Text('No workouts yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Your completed workouts will appear here.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(sessionHistoryProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: () async {
        ref.invalidate(sessionHistoryProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: historyAsync.when(
        data: (sessions) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Mode Switcher
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isCalendarMode ? 'Workout Calendar' : 'History List',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'BarlowCondensed',
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          _buildToggleButton(
                            icon: Icons.calendar_month_rounded,
                            label: 'Calendar',
                            isSelected: _isCalendarMode,
                            onTap: () => setState(() => _isCalendarMode = true),
                          ),
                          _buildToggleButton(
                            icon: Icons.view_list_rounded,
                            label: 'List',
                            isSelected: !_isCalendarMode,
                            onTap: () => setState(() => _isCalendarMode = false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isCalendarMode) ...[
                  _buildMonthHeader(),
                  const SizedBox(height: 12),
                  _buildCalendarGrid(sessions),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMM d, y').format(_selectedDate),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'BarlowCondensed',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSessionsForSelectedDate(sessions),
                ] else ...[
                  if (sessions.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _SessionHistoryCard(session: sessions[i]),
                    ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Failed to load history')),
      ),
    );
  }
}

class _SessionHistoryCard extends ConsumerWidget {
  final WorkoutSessionModel session;
  const _SessionHistoryCard({required this.session});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Delete Workout History?'),
        content: Text(
          'Are you sure you want to remove "${session.planName}" from your history? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await deleteWorkoutSession(ref, session.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout history deleted'), backgroundColor: AppColors.surfaceCard),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete history: ${extractApiError(e)}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = session.duration;
    final completedSets = session.exercises.expand((e) => e.sets).where((s) => s.isCompleted).length;
    final totalSets = session.exercises.expand((e) => e.sets).length;

    Color badgeColor = AppColors.primary;
    String badgeLabel = '';
    if (session.isRestDay) {
      badgeColor = AppColors.info;
      badgeLabel = 'REST DAY 🛋️';
    } else if (session.isCardio) {
      badgeColor = AppColors.warning;
      badgeLabel = 'CARDIO 🏃‍♀️';
    } else if (session.wasMakeUpSession) {
      badgeColor = AppColors.warning;
      badgeLabel = 'MAKE-UP';
    }

    return GestureDetector(
      onTap: session.isRestDay ? null : () => context.push('/session/${session.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: session.isRestDay
                ? AppColors.info.withValues(alpha: 0.3)
                : (session.isCardio ? AppColors.warning.withValues(alpha: 0.3) : AppColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.planName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'BarlowCondensed',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: session.isRestDay ? AppColors.info : AppColors.textPrimary,
                        ),
                  ),
                ),
                if (badgeLabel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 11,
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                  color: AppColors.surfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                          SizedBox(width: 8),
                          Text('Remove History', style: TextStyle(color: AppColors.error, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatChip(
                  icon: Icons.access_time_rounded,
                  label: session.completedAt != null ? DateFormat('MMM d, y').format(session.completedAt!) : '',
                ),
                if (session.isCardio) ...[
                  if (session.formattedCardioDuration != null)
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: session.formattedCardioDuration!,
                      color: AppColors.warning,
                    ),
                  if (session.cardioSpeed != null)
                    _StatChip(
                      icon: Icons.speed_rounded,
                      label: '${session.cardioSpeed} km/h',
                      color: AppColors.warning,
                    ),
                  if (session.cardioIncline != null)
                    _StatChip(
                      icon: Icons.terrain_rounded,
                      label: '${session.cardioIncline}% inc',
                      color: AppColors.warning,
                    ),
                ] else if (session.isRestDay) ...[
                  const _StatChip(
                    icon: Icons.bed_rounded,
                    label: 'Recovery Day',
                    color: AppColors.info,
                  ),
                ] else ...[
                  if (duration != null)
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: _formatDuration(duration),
                    ),
                  _StatChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: '$completedSets/$totalSets sets',
                    color: AppColors.accent,
                  ),
                ],
              ],
            ),
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${session.notes}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
