import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('More'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildMenuItem(
            context,
            icon: Icons.history_rounded,
            title: 'Workout History List',
            subtitle: 'View your past workouts in a list',
            onTap: () => context.push('/history'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: Icons.bar_chart_rounded,
            title: 'Exercise Stats',
            subtitle: 'View your progress and statistics',
            onTap: () => context.push('/stats'),
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context,
            icon: Icons.water_drop_outlined,
            title: 'Menstruation Logging',
            subtitle: 'Track your cycle',
            onTap: () => context.push('/menstruation'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
