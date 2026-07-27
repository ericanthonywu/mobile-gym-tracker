import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/network/api_client.dart';
import 'package:gym_tracker/core/network/api_endpoints.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:intl/intl.dart';

String extractApiError(dynamic e) {
  try {
    return e.response?.data?['error'] ?? e.toString();
  } catch (_) {
    return e.toString();
  }
}

Future<void> deleteWorkoutSession(WidgetRef ref, String id) async {
  await ApiClient.instance.delete(ApiEndpoints.sessionById(id));
  ref.invalidate(sessionHistoryProvider);
  ref.invalidate(recentSessionsProvider);
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

class SessionHistoryCard extends ConsumerWidget {
  final WorkoutSessionModel session;
  const SessionHistoryCard({super.key, required this.session});

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
