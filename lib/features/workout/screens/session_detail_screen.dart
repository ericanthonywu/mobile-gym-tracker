import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:intl/intl.dart';

class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String planName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Delete Workout History?'),
        content: Text(
          'Are you sure you want to remove "$planName" from your history? This action cannot be undone.',
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
        await deleteWorkoutSession(ref, sessionId);
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout history deleted'), backgroundColor: AppColors.surfaceCard),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete history: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Workout Details'),
        actions: [
          sessionAsync.when(
            data: (session) => IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Remove History',
              onPressed: () => _confirmDelete(context, ref, session.planName),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (session) => _buildDetail(context, session),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Could not load workout details.')),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, WorkoutSessionModel session) {
    final duration = session.duration;
    final totalSets = session.exercises.expand((e) => e.sets).length;
    final completedSets = session.exercises.expand((e) => e.sets).where((s) => s.isCompleted).length;
    final skippedSets = session.exercises.expand((e) => e.sets).where((s) => s.isSkipped).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.planName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              if (session.completedAt != null)
                Text(DateFormat('EEEE, MMMM d, y — h:mm a').format(session.completedAt!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              if (session.wasMakeUpSession) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.warningMuted, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Make-up workout', style: TextStyle(color: AppColors.warning, fontSize: 12, fontFamily: 'Barlow')),
                ),
              ],
              const SizedBox(height: 14),
              Row(children: [
                _StatBox(label: 'Duration', value: duration != null ? '${duration.inMinutes}m' : '—'),
                const SizedBox(width: 10),
                _StatBox(label: 'Sets Done', value: '$completedSets/$totalSets', color: AppColors.accent),
                if (skippedSets > 0) ...[
                  const SizedBox(width: 10),
                  _StatBox(label: 'Skipped', value: '$skippedSets', color: AppColors.error),
                ],
              ]),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Exercises detail
        ...session.exercises.map((ex) => _ExerciseDetail(exercise: ex)),

        if (session.notes != null && session.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Notes', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(session.notes!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, color: color)),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDetail extends StatelessWidget {
  final ExerciseSessionModel exercise;
  const _ExerciseDetail({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(exercise.exerciseName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
            ),
            if (exercise.isSkipped)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.errorMuted, borderRadius: BorderRadius.circular(6)),
                child: const Text('SKIPPED', style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          ...exercise.sets.map((set) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: set.isSkipped ? AppColors.errorMuted
                          : set.isCompleted ? AppColors.accentMuted
                          : AppColors.surfaceVariant,
                    ),
                    alignment: Alignment.center,
                    child: Text('${set.setNumber}',
                        style: TextStyle(
                          fontFamily: 'BarlowCondensed', fontSize: 13, fontWeight: FontWeight.w700,
                          color: set.isSkipped ? AppColors.error : set.isCompleted ? AppColors.accent : AppColors.textDisabled,
                        )),
                  ),
                  const SizedBox(width: 10),
                  if (set.isCompleted) ...[
                    Text('${set.reps ?? 0} reps',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (set.weightKg != null) ...[
                      Text('  ×  ${set.weightKg!.toStringAsFixed(1)} kg',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ] else if (set.isSkipped)
                    Text('Skipped', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error))
                  else
                    Text('Not completed', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textDisabled)),
                ]),
              )),
        ],
      ),
    );
  }
}
