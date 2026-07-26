import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/exercise_progress_model.dart';
import 'package:gym_tracker/features/workout/providers/stats_provider.dart';
import 'package:intl/intl.dart';

/// Exercise statistics screen with line chart for weight & reps progression.
class ExerciseStatsScreen extends ConsumerStatefulWidget {
  const ExerciseStatsScreen({super.key});

  @override
  ConsumerState<ExerciseStatsScreen> createState() => _ExerciseStatsScreenState();
}

class _ExerciseStatsScreenState extends ConsumerState<ExerciseStatsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int? _daysFor(StatsDateRange range) {
    switch (range) {
      case StatsDateRange.last30Days:
        return 30;
      case StatsDateRange.last90Days:
        return 90;
      case StatsDateRange.allTime:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statsNotifierProvider);
    final exercisesAsync = ref.watch(exerciseListProvider);
    final selectedExercise = state.selectedExercise;

    return Column(
      children: [
        // Exercise search picker
        _ExercisePicker(
          searchCtrl: _searchCtrl,
          exercisesAsync: exercisesAsync,
          selectedExercise: selectedExercise,
          onSelected: (name) {
            ref.read(statsNotifierProvider.notifier).selectExercise(name);
            _searchCtrl.clear();
          },
        ),

        if (selectedExercise != null) ...[
          // Date range selector
          _DateRangeSelector(
            selected: state.dateRange,
            onChanged: (r) => ref.read(statsNotifierProvider.notifier).setDateRange(r),
          ),

          // Chart area
          Expanded(
            child: _ProgressChartArea(
              exerciseName: selectedExercise,
              days: _daysFor(state.dateRange),
            ),
          ),
        ] else ...[
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart_rounded, size: 72, color: AppColors.textDisabled.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('Pick an exercise above',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('See your weight & reps progress\nover time with a clear chart.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise Picker
// ---------------------------------------------------------------------------
class _ExercisePicker extends StatefulWidget {
  final TextEditingController searchCtrl;
  final AsyncValue<List<String>> exercisesAsync;
  final String? selectedExercise;
  final ValueChanged<String> onSelected;

  const _ExercisePicker({
    required this.searchCtrl,
    required this.exercisesAsync,
    required this.selectedExercise,
    required this.onSelected,
  });

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  bool _showDropdown = false;
  List<String> _filtered = [];
  List<String> _allExercises = [];

  void _onSearch(String q) {
    setState(() {
      _showDropdown = q.isNotEmpty;
      _filtered = _allExercises
          .where((e) => e.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    widget.exercisesAsync.whenData((list) => _allExercises = list);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.selectedExercise != null)
            GestureDetector(
              onTap: () => setState(() {}),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.selectedExercise!,
                          style: const TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                    const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.searchCtrl,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: widget.selectedExercise != null
                  ? 'Change exercise...'
                  : 'Search exercise (e.g. Leg Extension)...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          if (_showDropdown && _filtered.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final name = _filtered[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.textSecondary),
                    title: Text(name, style: Theme.of(context).textTheme.bodyMedium),
                    onTap: () {
                      setState(() => _showDropdown = false);
                      widget.onSelected(name);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date Range Selector
// ---------------------------------------------------------------------------
class _DateRangeSelector extends StatelessWidget {
  final StatsDateRange selected;
  final ValueChanged<StatsDateRange> onChanged;
  const _DateRangeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: StatsDateRange.values.map((r) {
          final label = r == StatsDateRange.last30Days
              ? '30 Days'
              : r == StatsDateRange.last90Days
                  ? '90 Days'
                  : 'All Time';
          final isSelected = r == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress Chart Area
// ---------------------------------------------------------------------------
class _ProgressChartArea extends ConsumerWidget {
  final String exerciseName;
  final int? days;
  const _ProgressChartArea({required this.exerciseName, this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(
      exerciseProgressProvider((name: exerciseName, days: days)),
    );

    return progressAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Text('Could not load data', style: TextStyle(color: AppColors.textSecondary)),
      ),
      data: (data) {
        if (data.progress.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bar_chart_rounded, size: 56, color: AppColors.textDisabled),
                const SizedBox(height: 12),
                Text('No data yet for this period',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Personal Bests card
            _PersonalBestsCard(bests: data.bests, exerciseName: exerciseName),
            const SizedBox(height: 20),
            // Weight chart
            _ChartCard(
              title: 'Weight Progression',
              subtitle: 'Max weight per session (kg)',
              color: AppColors.primary,
              points: data.progress,
              getValue: (p) => p.maxWeightKg,
              yLabel: 'kg',
            ),
            const SizedBox(height: 16),
            // Reps chart
            _ChartCard(
              title: 'Total Reps',
              subtitle: 'Total reps per session',
              color: const Color(0xFF39E57A),
              points: data.progress,
              getValue: (p) => p.totalReps.toDouble(),
              yLabel: 'reps',
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Personal bests card
// ---------------------------------------------------------------------------
class _PersonalBestsCard extends StatelessWidget {
  final ExercisePersonalBests bests;
  final String exerciseName;
  const _PersonalBestsCard({required this.bests, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.surfaceVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 18),
            const SizedBox(width: 6),
            Text('Personal Bests — $exerciseName',
                style: const TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _BestStat(
              label: 'Best Weight',
              value: bests.bestWeightKg != null ? '${bests.bestWeightKg!.toStringAsFixed(1)} kg' : '—',
              icon: Icons.fitness_center_rounded,
            ),
            const SizedBox(width: 24),
            _BestStat(
              label: 'Best Reps',
              value: bests.bestReps != null ? '${bests.bestReps}' : '—',
              icon: Icons.repeat_rounded,
            ),
            const SizedBox(width: 24),
            _BestStat(
              label: 'Sessions',
              value: '${bests.totalSessions}',
              icon: Icons.calendar_today_rounded,
            ),
          ]),
        ],
      ),
    );
  }
}

class _BestStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _BestStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 12, color: AppColors.textDisabled),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textDisabled)),
        ]),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable line chart card
// ---------------------------------------------------------------------------
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<ExerciseProgressPoint> points;
  final double? Function(ExerciseProgressPoint) getValue;
  final String yLabel;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.points,
    required this.getValue,
    required this.yLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Build spots — filter null values
    final spots = <FlSpot>[];
    final dates = <DateTime>[];
    for (int i = 0; i < points.length; i++) {
      final v = getValue(points[i]);
      if (v != null && v > 0) {
        spots.add(FlSpot(i.toDouble(), v));
        dates.add(points[i].date);
      }
    }

    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final yPad = (maxY - minY) * 0.2 + 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
          Text(subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1),
                        style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (spots.length / 4).ceilToDouble().clamp(1, 999),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('d MMM').format(dates[idx]),
                            style: const TextStyle(color: AppColors.textDisabled, fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border),
                    left: BorderSide(color: AppColors.border),
                  ),
                ),
                minY: (minY - yPad).clamp(0, double.infinity),
                maxY: maxY + yPad,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: color,
                        strokeWidth: 2,
                        strokeColor: AppColors.background,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceVariant,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(s.y == s.y.roundToDouble() ? 0 : 1)} $yLabel',
                              TextStyle(
                                color: color,
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
