import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:gym_tracker/features/workout/widgets/session_history_card.dart';

class HistoryListScreen extends ConsumerWidget {
  const HistoryListScreen({super.key});

  Widget _buildEmptyState(BuildContext context) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Workout History'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceCard,
        onRefresh: () async {
          ref.invalidate(sessionHistoryProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: historyAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: _buildEmptyState(context),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(20),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => SessionHistoryCard(session: sessions[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => const Center(child: Text('Failed to load history')),
        ),
      ),
    );
  }
}
