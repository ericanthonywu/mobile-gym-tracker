import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/workout_plan_model.dart';


/// 7-day schedule editor — assign a plan to each day or mark as rest day.
class ScheduleEditorScreen extends ConsumerStatefulWidget {
  const ScheduleEditorScreen({super.key});

  @override
  ConsumerState<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _DayConfig {
  String? planId;
  bool isRestDay;
  _DayConfig({this.isRestDay = false});
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen> {
  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final _days = List.generate(7, (_) => _DayConfig(isRestDay: true));
  List<WorkoutPlanModel> _plans = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final [scheduleResp, plansResp] = await Future.wait([
        ApiClient.instance.get(ApiEndpoints.schedule),
        ApiClient.instance.get(ApiEndpoints.workoutPlans),
      ]);

      _plans = (plansResp.data['data'] as List)
          .map((e) => WorkoutPlanModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final schedule = scheduleResp.data['data'] as List;
      for (final d in schedule) {
        final idx = d['day_of_week'] as int;
        _days[idx].planId = d['plan_id'] as String?;
        _days[idx].isRestDay = d['is_rest_day'] as bool? ?? false;
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final days = _days.asMap().entries.map((e) => {
            'dayOfWeek': e.key,
            'planId': e.value.isRestDay ? null : e.value.planId,
            'isRestDay': e.value.isRestDay,
          }).toList();

      await ApiClient.instance.put(ApiEndpoints.schedule, data: {'days': days});
      if (mounted) context.pop();
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save schedule. Try again!'), backgroundColor: AppColors.error),
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
        title: const Text('Weekly Schedule'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _DayEditor(
                dayName: _dayNames[i],
                config: _days[i],
                plans: _plans,
                onChanged: () => setState(() {}),
              ),
            ),
    );
  }
}

class _DayEditor extends StatelessWidget {
  final String dayName;
  final _DayConfig config;
  final List<WorkoutPlanModel> plans;
  final VoidCallback onChanged;

  const _DayEditor({
    required this.dayName,
    required this.config,
    required this.plans,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(dayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'BarlowCondensed',
                        fontWeight: FontWeight.w700,
                      )),
              const Spacer(),
              Text('Rest Day', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              Switch(
                value: config.isRestDay,
                onChanged: (v) {
                  config.isRestDay = v;
                  if (v) config.planId = null;
                  onChanged();
                },
              ),
            ],
          ),
          if (!config.isRestDay) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: config.planId,
              decoration: const InputDecoration(
                hintText: 'Select a plan',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              dropdownColor: AppColors.surfaceVariant,
              style: Theme.of(context).textTheme.bodyMedium,
              items: plans.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
              onChanged: (v) {
                config.planId = v;
                onChanged();
              },
            ),
          ],
        ],
      ),
    );
  }
}
