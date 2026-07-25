import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/weight/models/weight_log_model.dart';
import 'package:gym_tracker/features/weight/providers/weight_provider.dart';
import 'package:intl/intl.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _chartRange = 'weekly';
  bool _isLogging = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _logWeight() async {
    final kg = double.tryParse(_weightCtrl.text);
    if (kg == null || kg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight in kg!')),
      );
      return;
    }
    setState(() => _isLogging = true);
    try {
      HapticFeedback.mediumImpact();
      await ApiClient.instance.post(ApiEndpoints.weightList, data: {
        'weightKg': kg,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });
      _weightCtrl.clear();
      _notesCtrl.clear();
      ref.invalidate(weightLatestProvider);
      ref.invalidate(weightChartProvider);
      ref.invalidate(weightSummaryProvider);
      ref.invalidate(weightListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ${kg.toStringAsFixed(1)} kg — great job tracking! 💪'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractApiError(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(weightLatestProvider);
    final summary = ref.watch(weightSummaryProvider(_chartRange));
    final chartData = ref.watch(weightChartProvider(_chartRange));
    final history = ref.watch(weightListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Weight Tracker'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Log weight input card
          _LogWeightCard(
            ctrl: _weightCtrl,
            notesCtrl: _notesCtrl,
            isLogging: _isLogging,
            latest: latest.valueOrNull,
            onLog: _logWeight,
          ),
          const SizedBox(height: 20),

          // Stats summary row
          summary.when(
            data: (s) => _SummaryRow(summary: s),
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Range toggle + chart
          _buildRangeToggle(),
          const SizedBox(height: 14),

          chartData.when(
            data: (points) => points.isEmpty
                ? _EmptyChart()
                : _WeightChart(points: points),
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          // History list
          history.when(
            data: (entries) => entries.isEmpty
                ? Center(child: Text('No weight entries yet. Start logging!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)))
                : Column(
                    children: entries.map((e) => _WeightHistoryRow(
                      entry: e,
                      onDelete: () async {
                        HapticFeedback.mediumImpact();
                        await ApiClient.instance.delete(ApiEndpoints.weightById(e.id));
                        ref.invalidate(weightLatestProvider);
                        ref.invalidate(weightChartProvider);
                        ref.invalidate(weightSummaryProvider);
                        ref.invalidate(weightListProvider);
                      },
                    )).toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRangeToggle() {
    return Row(
      children: ['weekly', 'monthly'].map((range) {
        final selected = _chartRange == range;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _chartRange = range),
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
// Log weight card
// ---------------------------------------------------------------------------
class _LogWeightCard extends StatelessWidget {
  final TextEditingController ctrl;
  final TextEditingController notesCtrl;
  final bool isLogging;
  final WeightLogModel? latest;
  final VoidCallback onLog;

  const _LogWeightCard({
    required this.ctrl,
    required this.notesCtrl,
    required this.isLogging,
    required this.latest,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E1A), AppColors.surfaceCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.monitor_weight_outlined, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Log Today\'s Weight', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.accent)),
            if (latest != null) ...[
              const Spacer(),
              Text(
                'Last: ${latest!.weightKg.toStringAsFixed(1)} kg',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '62.5',
                  suffixText: 'kg',
                  suffixStyle: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  hintText: 'Optional notes...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLogging ? null : onLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
              child: isLogging
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                  : const Text('LOG WEIGHT'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary stats row
// ---------------------------------------------------------------------------
class _SummaryRow extends StatelessWidget {
  final WeightSummaryModel summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final trendIcon = summary.trend == 'up'
        ? const Icon(Icons.trending_up_rounded, color: AppColors.error, size: 20)
        : summary.trend == 'down'
            ? const Icon(Icons.trending_down_rounded, color: AppColors.accent, size: 20)
            : const Icon(Icons.trending_flat_rounded, color: AppColors.textSecondary, size: 20);

    return Row(
      children: [
        _MiniStat(label: 'Current', value: summary.avgKg != null ? '${summary.avgKg!.toStringAsFixed(1)} kg' : '—'),
        const SizedBox(width: 8),
        _MiniStat(label: 'Min', value: summary.minKg != null ? '${summary.minKg!.toStringAsFixed(1)}' : '—', color: AppColors.accent),
        const SizedBox(width: 8),
        _MiniStat(label: 'Max', value: summary.maxKg != null ? '${summary.maxKg!.toStringAsFixed(1)}' : '—', color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              trendIcon,
              const SizedBox(height: 2),
              Text('Trend', style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, color: color)),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weight chart
// ---------------------------------------------------------------------------
class _WeightChart extends StatelessWidget {
  final List<WeightChartPoint> points;
  const _WeightChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final minY = points.map((p) => p.weightKg).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = points.map((p) => p.weightKg).reduce((a, b) => a > b ? a : b) + 2;

    final spots = points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weightKg)).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, _) => Text(val.toStringAsFixed(0),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontFamily: 'Barlow')),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (points.length / 4).ceilToDouble(),
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                  final date = points[idx].date;
                  final parts = date.split('-');
                  if (parts.length < 3) return const SizedBox.shrink();
                  return Text('${parts[2]}/${parts[1]}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontFamily: 'Barlow'));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.accent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.accent,
                  strokeWidth: 1.5,
                  strokeColor: AppColors.background,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AppColors.accent.withOpacity(0.25), AppColors.accent.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart_rounded, color: AppColors.textDisabled, size: 40),
            const SizedBox(height: 8),
            Text('No data yet — start logging your weight!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weight history row (swipe to delete)
// ---------------------------------------------------------------------------
class _WeightHistoryRow extends StatelessWidget {
  final WeightLogModel entry;
  final VoidCallback onDelete;
  const _WeightHistoryRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.errorMuted, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE, MMM d').format(entry.loggedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  if (entry.notes != null && entry.notes!.isNotEmpty)
                    Text(entry.notes!, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            Text(
              '${entry.weightKg.toStringAsFixed(1)} kg',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
