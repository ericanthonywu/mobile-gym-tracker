import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/utils/widget_data_service.dart';
import 'package:gym_tracker/features/meals/models/meal_model.dart';
import 'package:gym_tracker/features/meals/providers/meals_provider.dart';
import 'package:gym_tracker/features/weight/models/weight_log_model.dart';
import 'package:gym_tracker/features/weight/providers/weight_provider.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Today's schedule provider
// ---------------------------------------------------------------------------
final todayScheduleProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final response = await ApiClient.instance.get(ApiEndpoints.scheduleToday);
    return response.data as Map<String, dynamic>;
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Skip day banner
                today.when(
                  data: (data) => _buildSkipBanner(context, ref, data),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                // Today's Quick Overview Dual Widget (Plan + Weight)
                _buildQuickOverviewWidget(
                  context,
                  today.valueOrNull,
                  latestWeight.valueOrNull,
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
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
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

  /// Side-by-side Home Screen Style Widget (Today's Plan + Last Weight)
  Widget _buildQuickOverviewWidget(
    BuildContext context,
    Map<String, dynamic>? todayData,
    WeightLogModel? weight,
  ) {
    final todayMap = todayData?['today'] as Map<String, dynamic>? ?? {};
    final plan = todayMap['plan'] as Map<String, dynamic>?;
    final isRestDay = todayMap['isRestDay'] as bool? ?? false;
    final planName = isRestDay ? 'Rest Day 😴' : (plan?['name'] as String? ?? 'No Plan');
    final exercisesCount = (plan?['exercises'] as List<dynamic>? ?? []).length;

    // Sync values with iOS HomeWidget
    if (planName.isNotEmpty) {
      WidgetDataService.updateTodayPlan(planName, isRestDay: isRestDay);
    }
    if (weight != null) {
      WidgetDataService.updateLastWeight(
        weight.weightKg,
        DateFormat('MMM d').format(weight.loggedAt),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E38), Color(0xFF141424)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚡ QUICK OVERVIEW WIDGET',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.widgets_outlined, color: AppColors.textSecondary, size: 16),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Today's Plan Half
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go('/workout'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 6),
                            Text('Today\'s Plan', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          planName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                color: isRestDay ? AppColors.info : AppColors.textPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isRestDay
                              ? 'Recovery Time'
                              : '$exercisesCount exercise${exercisesCount != 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Last Weight Half
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go('/weight'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.monitor_weight_rounded, color: AppColors.accent, size: 16),
                            const SizedBox(width: 6),
                            Text('Last Weight', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weight != null ? '${weight.weightKg.toStringAsFixed(1)} kg' : 'No Log',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          weight != null
                              ? DateFormat('MMM d').format(weight.loggedAt)
                              : 'Tap to log',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
