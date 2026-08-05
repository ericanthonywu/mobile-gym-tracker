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
import 'package:gym_tracker/features/weight/models/weight_log_model.dart';
import 'package:gym_tracker/features/weight/providers/weight_provider.dart';
import 'package:gym_tracker/features/menstruation/models/menstruation_log_model.dart';
import 'package:gym_tracker/features/menstruation/providers/menstruation_provider.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:gym_tracker/features/workout/screens/pre_session_editor_screen.dart';
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
    final recentSessions = ref.watch(recentSessionsProvider);
    final menstruationAsync = ref.watch(menstruationLogsProvider);
    final activeSessionAsync = ref.watch(activeSessionNotifierProvider);
    final activeSession = activeSessionAsync.valueOrNull;

    // Trigger gentle notification schedule if menstruation is active
    final menstruationLogs = menstruationAsync.valueOrNull ?? [];
    MenstruationLogModel? activeLog;
    try {
      activeLog = menstruationLogs.firstWhere((l) => l.endDate == null);
    } catch (_) {
      activeLog = null;
    }
    if (activeLog != null) {
      final todayMap = today.valueOrNull?['notificationCheck'] as Map<String, dynamic>?;
      NotificationService.scheduleDailyReminders(
        yesterdaySkipped: todayMap?['yesterdaySkipped'] as bool? ?? false,
        skippedPlanName: todayMap?['yesterdayPlanName'] as String?,
        isMenstruationDay: true,
        menstruationDayNumber: DateTime.now().difference(activeLog.startDate).inDays + 1,
      );
    }

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
          ref.invalidate(recentSessionsProvider);
          ref.invalidate(menstruationLogsProvider);
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
                  // Menstruation daily tracker card
                  _buildMenstruationCard(context, ref, menstruationAsync),
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

  Widget _buildMenstruationCard(BuildContext context, WidgetRef ref, AsyncValue<List<MenstruationLogModel>> menstruationAsync) {
    return menstruationAsync.when(
      data: (logs) {
        MenstruationLogModel? activeLog;
        try {
          activeLog = logs.firstWhere((l) => l.endDate == null);
        } catch (_) {
          activeLog = null;
        }

        final isActive = activeLog != null;
        final accentColor = isActive ? const Color(0xFFFF6B8A) : AppColors.textSecondary;

        int dayNum = 0;
        if (activeLog != null) {
          final now = DateTime.now();
          final start = DateTime(activeLog.startDate.year, activeLog.startDate.month, activeLog.startDate.day);
          final today = DateTime(now.year, now.month, now.day);
          dayNum = today.difference(start).inDays + 1;
        }

        return GestureDetector(
          onTap: () => context.push('/menstruation'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1F0D14) : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? accentColor.withValues(alpha: 0.4) : AppColors.border,
                width: isActive ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? 'Cycle Day $dayNum 🌸' : 'Period Tracker',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isActive ? accentColor : AppColors.textPrimary,
                            ),
                      ),
                      Text(
                        activeLog != null
                            ? 'Started ${DateFormat('MMM d').format(activeLog.startDate)} · Tap to manage'
                            : 'Tap to start or view history',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        );
      },
      loading: () => const _SkeletonCard(height: 68),
      error: (_, __) => const SizedBox.shrink(),
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
    final markedRestDayToday = todayData['markedRestDayToday'] as bool? ?? false;
    final completedToday = todayData['completedToday'] as bool? ?? false;
    final dayName = todayData['dayName'] as String? ?? '';
    final exercises = plan?['exercises'] as List<dynamic>? ?? [];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(dayName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary)),
              ),
              if (markedRestDayToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bed_rounded, color: AppColors.info, size: 14),
                      SizedBox(width: 4),
                      Text('REST DAY MARKED', style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else if (completedToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 14),
                      SizedBox(width: 4),
                      Text('COMPLETED 🏆', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (plan == null || isRestDay) ...[
            Text('Rest Day 😴', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('No workout scheduled for today. Feel free to rest — or start a quick workout!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push(
                    '/session/pre-editor?quick=true&planName=Quick+Workout',
                    extra: <ExerciseEntry>[],
                  );
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('QUICK WORKOUT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
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
            if (!completedToday) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final planId = plan['id'] as String?;
                    final planName = plan['name'] as String? ?? 'Workout';
                    // Build initial exercise list from plan template
                    final initialExercises = (exercises as List<dynamic>).map((e) {
                      final ex = e as Map<String, dynamic>;
                      return ExerciseEntry.fromPlanExercise(ex);
                    }).toList();
                    // Navigate to pre-session editor with plan data as GoRouter extra
                    context.push(
                      '/session/pre-editor?planId=${planId ?? ''}&planName=${Uri.encodeComponent(planName)}',
                      extra: initialExercises,
                    );
                  },
                  icon: const Icon(Icons.fitness_center_rounded),
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
              const SizedBox(height: 10),
            ],
          ],

          // Compliment banner when workout or rest day is done today
          if (completedToday && !markedRestDayToday) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Awesome job crushing your workout today, Vivian! 🔥 You\'re making amazing progress!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (markedRestDayToday) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bed_rounded, color: AppColors.info, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enjoy your well-deserved rest today, Vivian! 🛋️ Recovery builds strength!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quick actions row: Quick Workout, Cardio & Rest Day
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push(
                      '/session/pre-editor?quick=true&planName=Quick+Workout',
                      extra: <ExerciseEntry>[],
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.primary),
                  label: const Text(
                    'QUICK WORKOUT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    showDialog(
                      context: context,
                      builder: (_) => const _LogCardioDialog(),
                    );
                  },
                  icon: const Icon(Icons.directions_run_rounded, size: 16, color: AppColors.warning),
                  label: const Text(
                    'LOG CARDIO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (!completedToday && !markedRestDayToday) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      try {
                        await markRestDayToday(ref);
                        ref.invalidate(todayScheduleProvider);
                        await NotificationService.checkAndScheduleReminders();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Today marked as Rest Day! Enjoy your recovery 🛋️'),
                              backgroundColor: AppColors.surfaceCard,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to mark rest day: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.bed_rounded,
                      size: 16,
                      color: AppColors.info,
                    ),
                    label: const Text(
                      'REST DAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.info.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
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

  // Only visible starting from August 9 at 06:00 WIB (JKT time) onwards.
  bool get _isGraduationDay {
    final jktNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final gradStart = DateTime.utc(2026, 8, 9, 6, 0);
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

class _LogCardioDialog extends ConsumerStatefulWidget {
  const _LogCardioDialog();

  @override
  ConsumerState<_LogCardioDialog> createState() => _LogCardioDialogState();
}

class _LogCardioDialogState extends ConsumerState<_LogCardioDialog> {
  static const _activities = [
    'Treadmill',
    'Outdoor Run',
    'Cycling',
    'Walking',
    'Elliptical',
    'Stair Master',
    'Rowing',
    'Other',
  ];

  late String _selectedActivity;
  final _durationController = TextEditingController(text: '30');
  final _speedController = TextEditingController();
  final _inclineController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedActivity = _activities.first;
  }

  @override
  void dispose() {
    _durationController.dispose();
    _speedController.dispose();
    _inclineController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.directions_run_rounded, color: AppColors.warning, size: 24),
          const SizedBox(width: 10),
          Text(
            'Log Cardio Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Type', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedActivity,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceVariant,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                  items: _activities.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text(a, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedActivity = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duration (mins)', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. 30',
                          hintStyle: const TextStyle(color: AppColors.textDisabled),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Speed (km/h)', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _speedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. 6.5',
                          hintStyle: const TextStyle(color: AppColors.textDisabled),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Incline (%)', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _inclineController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. 3.0 (optional)',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Text('Notes', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Warmup 5 mins, steady pace.',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  final mins = int.tryParse(_durationController.text.trim()) ?? 0;
                  final speedVal = double.tryParse(_speedController.text.trim());
                  final inclineVal = double.tryParse(_inclineController.text.trim());
                  final notesVal = _notesController.text.trim();

                  setState(() => _isSubmitting = true);
                  try {
                    await logCardioSession(
                      ref,
                      activityName: _selectedActivity,
                      durationSeconds: mins > 0 ? mins * 60 : null,
                      speed: speedVal,
                      incline: inclineVal,
                      notes: notesVal.isNotEmpty ? notesVal : null,
                    );
                    ref.invalidate(todayScheduleProvider);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cardio logged: $_selectedActivity 🏃‍♀️'),
                          backgroundColor: AppColors.surfaceCard,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() => _isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to log cardio: $e')),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
              : const Text('SAVE CARDIO'),
        ),
      ],
    );
  }
}
