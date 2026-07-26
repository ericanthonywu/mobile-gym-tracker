import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/utils/notification_service.dart';
import 'package:gym_tracker/core/utils/widget_data_service.dart';
import 'package:gym_tracker/features/dashboard/screens/graduation_screen.dart';
import 'package:gym_tracker/features/meals/models/meal_model.dart';
import 'package:gym_tracker/features/meals/providers/meals_provider.dart';
import 'package:gym_tracker/features/weight/models/weight_log_model.dart';
import 'package:gym_tracker/features/weight/providers/weight_provider.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Today's schedule provider
// ---------------------------------------------------------------------------
final todayScheduleProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final response = await ApiClient.instance.get(ApiEndpoints.scheduleToday);
    final data = response.data as Map<String, dynamic>;

    // Update notification reminders with yesterday's skip check
    final notifCheck = data['notificationCheck'] as Map<String, dynamic>?;
    if (notifCheck != null) {
      final yesterdaySkipped = notifCheck['yesterdaySkipped'] as bool? ?? false;
      final skippedPlanName = notifCheck['yesterdayPlanName'] as String?;
      NotificationService.scheduleDailyReminders(
        yesterdaySkipped: yesterdaySkipped,
        skippedPlanName: skippedPlanName,
      );
    }

    return data;
  } catch (_) {
    return {};
  }
});

// ---------------------------------------------------------------------------
// Dashboard Screen
// ---------------------------------------------------------------------------
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayScheduleProvider);
    final latestWeight = ref.watch(weightLatestProvider);
    final todayMeals = ref.watch(mealsTodayProvider);
    final recentSessions = ref.watch(recentSessionsProvider);
    final activeSessionAsync = ref.watch(activeSessionNotifierProvider);
    final activeSession = activeSessionAsync.valueOrNull;

    // Automatically sync iOS Home Screen Widget in background
    if (today.valueOrNull != null) {
      final todayMap = today.valueOrNull!['today'] as Map<String, dynamic>? ?? {};
      final plan = todayMap['plan'] as Map<String, dynamic>?;
      final isRest = todayMap['isRestDay'] as bool? ?? false;
      final name = isRest ? 'Rest Day 😴' : (plan?['name'] as String? ?? '');
      final w = latestWeight.valueOrNull;
      if (name.isNotEmpty) {
        WidgetDataService.syncWidgetData(
          planName: name,
          isRestDay: isRest,
          weightKg: w?.weightKg,
          dateStr: w != null ? DateFormat('MMM d').format(w.loggedAt) : null,
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _GraduationEasterEggFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceCard,
        onRefresh: () async {
          ref.invalidate(todayScheduleProvider);
          ref.invalidate(weightLatestProvider);
          ref.invalidate(mealsTodayProvider);
          ref.invalidate(recentSessionsProvider);
          ref.read(activeSessionNotifierProvider.notifier).load();
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Ongoing Workout Hero Card (when active)
                  if (activeSession != null && activeSession.isActive) ...[
                    _OngoingWorkoutHeroCard(session: activeSession),
                    const SizedBox(height: 16),
                  ],
                  // Skip day banner
                  today.when(
                    data: (data) => _buildSkipBanner(context, ref, data),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // Today's workout card
                  today.when(
                    data: (data) => _buildTodayCard(context, ref, data),
                    loading: () => const _SkeletonCard(height: 180),
                    error: (_, __) => const _ErrorCard(message: 'Couldn\'t load today\'s plan'),
                  ),
                  const SizedBox(height: 16),
                  // Weight snapshot
                  latestWeight.when(
                    data: (w) => _buildWeightCard(context, ref, w),
                    loading: () => const _SkeletonCard(height: 110),
                    error: (_, __) => const _ErrorCard(message: 'Couldn\'t load weight'),
                  ),
                  const SizedBox(height: 16),
                  // Meals today
                  todayMeals.when(
                    data: (meals) => _buildMealsCard(context, ref, meals),
                    loading: () => const _SkeletonCard(height: 130),
                    error: (_, __) => const _ErrorCard(message: 'Couldn\'t load meals'),
                  ),
                  const SizedBox(height: 24),
                  // Last 5 Workout History
                  recentSessions.when(
                    data: (history) => _buildRecentWorkoutsCard(context, history),
                    loading: () => const _SkeletonCard(height: 160),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);
    final dateStr = DateFormat('d MMMM yyyy').format(now);

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF0F0F14)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey Vivian! 👋',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dayName, $dateStr',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/v_logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipBanner(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final banner = data['skippedBanner'];
    if (banner == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF422006), Color(0xFF1A1A2E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Carry-over workout!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.warning)),
                const SizedBox(height: 4),
                Text(banner['message'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
            onPressed: () async {
              try {
                await ApiClient.instance.post(ApiEndpoints.scheduleDismissSkip(banner['skipId'] as String));
                ref.invalidate(todayScheduleProvider);
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final todayData = data['today'] as Map<String, dynamic>? ?? {};
    final plan = todayData['plan'] as Map<String, dynamic>?;
    final isRestDay = todayData['isRestDay'] as bool? ?? false;
    final dayName = todayData['dayName'] as String? ?? '';
    final exercises = plan?['exercises'] as List<dynamic>? ?? [];

    if (isRestDay || plan == null) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.hotel_rounded, color: AppColors.info, size: 22),
              const SizedBox(width: 10),
              Text('Today — $dayName',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 12),
            Text('Rest Day 😴', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('No workout scheduled. Take it easy — your muscles are recovering! 💤',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(dayName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(plan['name'] as String,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Text('${exercises.length} exercise${exercises.length != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: exercises.take(3).map((e) {
              final ex = e as Map<String, dynamic>;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(ex['name'] as String,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary)),
              );
            }).toList()
              ..addAll(exercises.length > 3
                  ? [Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                      child: Text('+${exercises.length - 3} more',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                    )]
                  : []),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final planId = plan['id'] as String?;
                if (planId != null) {
                  try {
                    await ref.read(activeSessionNotifierProvider.notifier).startSession(planId: planId);
                  } catch (_) {}
                }
                if (context.mounted) {
                  context.push('/session/active');
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('START WORKOUT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCard(BuildContext context, WidgetRef ref, WeightLogModel? weight) {
    return _card(
      onTap: () => context.go('/weight'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.monitor_weight_outlined, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('Weight', style: Theme.of(context).textTheme.titleSmall),
                ]),
                const SizedBox(height: 8),
                weight != null
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(weight.weightKg.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: AppColors.accent,
                                    fontFamily: 'BarlowCondensed',
                                    fontWeight: FontWeight.w700,
                                  )),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('kg', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                          ),
                        ],
                      )
                    : Text('No entry yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                if (weight != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Logged ${DateFormat('MMM d').format(weight.loggedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildMealsCard(BuildContext context, WidgetRef ref, List<MealItemModel> meals) {
    if (meals.isEmpty) {
      return _card(
        onTap: () => context.go('/meals'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.restaurant_rounded, color: AppColors.chartBlue, size: 20),
              const SizedBox(width: 8),
              Text('Meals Today', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ]),
            const SizedBox(height: 12),
            Text('Set up your meals in the Meals tab!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final checkedCount = meals.where((m) => m.isChecked).length;
    return _card(
      onTap: () => context.go('/meals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.restaurant_rounded, color: AppColors.chartBlue, size: 20),
            const SizedBox(width: 8),
            Text('Meals Today', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text('$checkedCount/${meals.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: checkedCount == meals.length ? AppColors.accent : AppColors.textSecondary,
                    )),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ]),
          const SizedBox(height: 12),
          Row(
            children: meals.map((m) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: m.isChecked ? AppColors.accentMuted : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: m.isChecked ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        m.isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: m.isChecked ? AppColors.accent : AppColors.textDisabled,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.name,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: m.isChecked ? AppColors.accent : AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentWorkoutsCard(BuildContext context, List<WorkoutSessionModel> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Recent Workout History',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/workout'),
              child: const Text('See All', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...history.take(5).map((session) {
          final started = session.startedAt;
          final dateStr = DateFormat('MMM d, h:mm a').format(started);

          String durationStr = '--';
          if (session.completedAt != null) {
            final diff = session.completedAt!.difference(started);
            final mins = diff.inMinutes;
            final hrs = diff.inHours;
            if (hrs > 0) {
              durationStr = '${hrs}h ${mins.remainder(60)}m';
            } else {
              durationStr = '${mins}m';
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.planName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${session.exercises.length} exercises',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.accent, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        durationStr,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
    );
  }
}

// ---------------------------------------------------------------------------
// Ongoing Active Workout Hero Card on Dashboard
// ---------------------------------------------------------------------------
class _OngoingWorkoutHeroCard extends StatefulWidget {
  final WorkoutSessionModel session;
  const _OngoingWorkoutHeroCard({required this.session});

  @override
  State<_OngoingWorkoutHeroCard> createState() => _OngoingWorkoutHeroCardState();
}

class _OngoingWorkoutHeroCardState extends State<_OngoingWorkoutHeroCard> {
  Timer? _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
  }

  void _updateElapsed() {
    if (mounted) {
      final now = DateTime.now();
      final diff = now.difference(widget.session.startedAt);
      setState(() {
        _elapsed = diff;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours;
    final mins = _elapsed.inMinutes.remainder(60);
    final secs = _elapsed.inSeconds.remainder(60);

    final timeStr = '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final activeEx = widget.session.exercises.firstWhere(
      (e) => !e.isAllCompleted && !e.isSkipped,
      orElse: () => widget.session.exercises.first,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1C0C), Color(0xFF141424)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'WORKOUT IN PROGRESS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textOnPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.session.planName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Current: ${activeEx.exerciseName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/session/active'),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('CONTINUE WORKOUT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🎓 Graduation Easter Egg FAB
// A discreet envelope FAB (bottom-right) with a looping jump animation.
// Only visible on August 9 from 06:00 WIB onwards.
// ---------------------------------------------------------------------------
class _GraduationEasterEggFab extends StatefulWidget {
  @override
  State<_GraduationEasterEggFab> createState() => _GraduationEasterEggFabState();
}

class _GraduationEasterEggFabState extends State<_GraduationEasterEggFab>
    with TickerProviderStateMixin {
  late final AnimationController _jumpCtrl;
  late final AnimationController _pulseCtrl; // expanding ring highlight
  late final Animation<double> _translateY;
  late final Animation<double> _scaleY; // vertical squash/stretch
  late final Animation<double> _scaleX; // inverse horizontal for rubber-ball feel
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  // Only visible starting from August 6 at 06:00 WIB (JKT time) onwards.
  bool get _isGraduationDay {
    final jktNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final gradStart = DateTime.utc(2026, 8, 6, 6, 0);
    return !jktNow.isBefore(gradStart);
  }

  @override
  void initState() {
    super.initState();

    // Pulsing ring: expands from 1x to 1.8x while fading out, loops every 1.8s.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 1.9)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeIn));

    // Total duration: 1100 ms
    // Phases (weights sum = 100):
    //  [0–8]   anticipation squish (crouch before jump)
    //  [8–35]  launch: fast ascent with vertical stretch
    //  [35–55] arc peak / hang — slow, near-zero velocity
    //  [55–70] fast fall back down
    //  [70–82] landing squash (wide & flat on impact)
    //  [82–92] first rebound (mini-bounce)
    //  [92–100] settle back to rest
    _jumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Y-translation: positive = down, negative = up (jumping higher)
    _translateY = TweenSequence<double>([
      // Anticipation: sink down slightly
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 5.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 8,
      ),
      // Launch → high ascent
      TweenSequenceItem(
        tween: Tween(begin: 5.0, end: -48.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
      // Hang at peak (slow arc)
      TweenSequenceItem(
        tween: Tween(begin: -48.0, end: -44.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      // Fast fall down
      TweenSequenceItem(
        tween: Tween(begin: -44.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Landing squash (stay ground level while squashing)
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 12,
      ),
      // Rebound mini-bounce
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -14.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -14.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 5,
      ),
      // Settle
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 8,
      ),
    ]).animate(_jumpCtrl);

    // ScaleY: squash on impact, stretch during flight
    _scaleY = TweenSequence<double>([
      // Anticipation squish (crouch)
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.78)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 8,
      ),
      // Stretch on launch
      TweenSequenceItem(
        tween: Tween(begin: 0.78, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
      // At peak — nearly round
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      // Falling — re-stretch slightly
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Landing squash — wide & flat
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 0.68)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      // Rebound up
      TweenSequenceItem(
        tween: Tween(begin: 0.68, end: 1.10)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 5,
      ),
      // Rebound down
      TweenSequenceItem(
        tween: Tween(begin: 1.10, end: 0.92)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 5,
      ),
      // Settle to 1.0
      TweenSequenceItem(
        tween: Tween(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 8,
      ),
    ]).animate(_jumpCtrl);

    // ScaleX: inverse of scaleY — wider when squashed, narrower when stretched
    _scaleX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 0.82)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 27,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.82, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.90)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Landing — spread wide
      TweenSequenceItem(
        tween: Tween(begin: 0.90, end: 1.32)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.32, end: 0.94)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.94, end: 1.06)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 8,
      ),
    ]).animate(_jumpCtrl);

    // Loop: jump then rest for 2 seconds.
    _scheduleNextJump();
  }

  void _scheduleNextJump() {
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      _jumpCtrl.forward(from: 0).then((_) {
        if (mounted) _scheduleNextJump();
      });
    });
  }

  @override
  void dispose() {
    _jumpCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGraduationDay) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_jumpCtrl, _pulseCtrl]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _translateY.value),
        child: Transform.scale(
          scaleX: _scaleX.value,
          scaleY: _scaleY.value,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => GraduationScreen.show(context),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // ✨ Pulsing gold ring highlight
                  Transform.scale(
                    scale: _pulseScale.value,
                    child: Opacity(
                      opacity: _pulseOpacity.value,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD700),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF5C3D00), Color(0xFF3D2800)],
                      center: Alignment.topLeft,
                      radius: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.mail_rounded,
                    color: Color(0xFFFFD700),
                    size: 26,
                  ),
                ),
                  // 🔴 Unread message indicator badge
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3D2800),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
