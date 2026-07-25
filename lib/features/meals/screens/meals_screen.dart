import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/meals/models/meal_model.dart';
import 'package:gym_tracker/features/meals/providers/meals_provider.dart';
import 'package:intl/intl.dart';

class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  String _summaryRange = 'weekly';

  @override
  Widget build(BuildContext context) {
    final todayMeals = ref.watch(mealsTodayProvider);
    final summary = ref.watch(mealSummaryProvider(_summaryRange));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Healthy Meals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showMealSettings(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Today's meals header
          _SectionHeader(title: 'Today\'s Meals', icon: Icons.today_rounded),
          const SizedBox(height: 12),

          todayMeals.when(
            data: (meals) {
              if (meals.isEmpty) {
                return _EmptyMeals(onSetup: () => _showMealSettings(context));
              }

              final checkedCount = meals.where((m) => m.isChecked).length;
              return Column(
                children: [
                  // Progress indicator
                  _MealProgressCard(checkedCount: checkedCount, totalCount: meals.length),
                  const SizedBox(height: 12),
                  ...meals.map((meal) => _MealToggleCard(
                    meal: meal,
                    onToggle: (isChecked) => _toggleMeal(meal.mealSettingId, isChecked),
                  )),
                ],
              );
            },
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            )),
            error: (_, __) => const Center(child: Text('Couldn\'t load meals')),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: 'My Track Record', icon: Icons.bar_chart_rounded),
          const SizedBox(height: 10),

          // Range toggle
          _buildRangeToggle(context),
          const SizedBox(height: 14),

          // Compliance chart
          summary.when(
            data: (s) => s.byDate.isEmpty
                ? _EmptyChart()
                : _MealComplianceChart(summary: s),
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _toggleMeal(String mealSettingId, bool isChecked) async {
    HapticFeedback.selectionClick();
    try {
      await ApiClient.instance.patch(ApiEndpoints.mealToggle, data: {
        'mealSettingId': mealSettingId,
        'isChecked': isChecked,
      });
      ref.invalidate(mealsTodayProvider);
      ref.invalidate(mealSummaryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractApiError(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showMealSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MealSettingsSheet(
        onChanged: () {
          ref.invalidate(mealSettingsProvider);
          ref.invalidate(mealsTodayProvider);
        },
      ),
    );
  }

  Widget _buildRangeToggle(BuildContext context) {
    return Row(
      children: ['weekly', 'monthly'].map((range) {
        final selected = _summaryRange == range;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _summaryRange = range),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                range == 'weekly' ? 'Last 7 Days' : 'Last 30 Days',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress card
// ---------------------------------------------------------------------------
class _MealProgressCard extends StatelessWidget {
  final int checkedCount;
  final int totalCount;
  const _MealProgressCard({required this.checkedCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final pct = totalCount > 0 ? checkedCount / totalCount : 0.0;
    final allDone = checkedCount == totalCount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: allDone ? AppColors.accentMuted : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: allDone ? AppColors.accent.withOpacity(0.5) : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone ? 'All meals done! You\'re crushing it today 🎉' : '$checkedCount of $totalCount meals logged today',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: allDone ? AppColors.accent : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(allDone ? AppColors.accent : AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text('${(pct * 100).round()}%',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                    color: allDone ? AppColors.accent : AppColors.primary,
                  )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal toggle card
// ---------------------------------------------------------------------------
class _MealToggleCard extends StatefulWidget {
  final MealItemModel meal;
  final ValueChanged<bool> onToggle;
  const _MealToggleCard({required this.meal, required this.onToggle});

  @override
  State<_MealToggleCard> createState() => _MealToggleCardState();
}

class _MealToggleCardState extends State<_MealToggleCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.meal.isChecked;
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onToggle(!checked); },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: checked ? AppColors.accentMuted : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: checked ? AppColors.accent.withOpacity(0.6) : AppColors.border,
              width: checked ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? AppColors.accent : Colors.transparent,
                  border: Border.all(
                    color: checked ? AppColors.accent : AppColors.border,
                    width: 2,
                  ),
                ),
                child: checked
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 14),
              Text(
                widget.meal.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: checked ? AppColors.accent : AppColors.textPrimary,
                      decoration: checked ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.accent,
                    ),
              ),
              const Spacer(),
              if (checked)
                const Text('✓', style: TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meals compliance bar chart
// ---------------------------------------------------------------------------
class _MealComplianceChart extends StatelessWidget {
  final MealSummaryModel summary;
  const _MealComplianceChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    // Stats row
    return Column(
      children: [
        // Stats
        Row(
          children: [
            _StatPill(label: 'On Track', value: '${summary.compliancePct}%', color: AppColors.accent),
            const SizedBox(width: 8),
            _StatPill(label: 'Logged', value: '${summary.totalChecked}', color: AppColors.primary),
            const SizedBox(width: 8),
            _StatPill(label: 'Skipped', value: '${summary.totalSkipped}', color: AppColors.error),
          ],
        ),
        const SizedBox(height: 14),

        // Bar chart
        Container(
          height: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: summary.mealsPerDay.toDouble(),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (val, _) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= summary.byDate.length) return const SizedBox.shrink();
                      final rawDate = summary.byDate[idx].date;
                      final dt = DateTime.tryParse(rawDate);
                      final label = dt != null
                          ? (summary.range == 'weekly' ? DateFormat('E').format(dt) : DateFormat('d/M').format(dt))
                          : rawDate;
                      return Text(
                        label,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontFamily: 'Barlow'),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: summary.byDate.asMap().entries.map((entry) {
                final d = entry.value;
                final checked = d.checkedCount.toDouble();
                final skipped = (d.totalCount - d.checkedCount).toDouble();
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: d.totalCount.toDouble().clamp(0, summary.mealsPerDay.toDouble()),
                      width: 14,
                      borderRadius: BorderRadius.circular(4),
                      rodStackItems: [
                        BarChartRodStackItem(0, checked, AppColors.accent),
                        if (skipped > 0)
                          BarChartRodStackItem(checked, checked + skipped, AppColors.errorMuted),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, color: color)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------
class _EmptyMeals extends StatelessWidget {
  final VoidCallback onSetup;
  const _EmptyMeals({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        const Icon(Icons.restaurant_menu_rounded, color: AppColors.textDisabled, size: 48),
        const SizedBox(height: 12),
        Text('No meals set up yet!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text('Tap the settings icon to add your meals (Breakfast, Lunch, etc.)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDisabled), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onSetup,
          icon: const Icon(Icons.add),
          label: const Text('SET UP MEALS'),
        ),
      ]),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Center(child: Text('No meal data yet', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 20),
      const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Meal settings bottom sheet
// ---------------------------------------------------------------------------
class _MealSettingsSheet extends ConsumerStatefulWidget {
  final VoidCallback onChanged;
  const _MealSettingsSheet({required this.onChanged});

  @override
  ConsumerState<_MealSettingsSheet> createState() => _MealSettingsSheetState();
}

class _MealSettingsSheetState extends ConsumerState<_MealSettingsSheet> {
  final _newMealCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _newMealCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _newMealCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ApiClient.instance.post(ApiEndpoints.mealSettings, data: {'name': name});
      _newMealCtrl.clear();
      ref.invalidate(mealSettingsProvider);
      ref.invalidate(mealsTodayProvider);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractApiError(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ApiClient.instance.delete(ApiEndpoints.mealSettingById(id));
      ref.invalidate(mealSettingsProvider);
      ref.invalidate(mealsTodayProvider);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractApiError(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(mealSettingsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meal Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Add or remove the meals you track every day.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),

                  // Add new meal
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _newMealCtrl,
                        decoration: const InputDecoration(hintText: 'e.g. Breakfast, Snack...'),
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _adding ? null : _add,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50), padding: const EdgeInsets.symmetric(horizontal: 16)),
                      child: _adding
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                          : const Text('Add'),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.border),

            Expanded(
              child: settingsAsync.when(
                data: (settings) => settings.isEmpty
                    ? Center(child: Text('No meals yet. Add some above!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)))
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(20),
                        itemCount: settings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = settings[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(children: [
                              const Icon(Icons.drag_handle_rounded, color: AppColors.textDisabled, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(s.name, style: Theme.of(context).textTheme.bodyMedium)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                onPressed: () => _delete(s.id),
                              ),
                            ]),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
