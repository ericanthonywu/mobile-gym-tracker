import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/set_comparison_model.dart';

/// Full-screen overlay shown briefly after recording a set.
/// Displays whether performance improved, stayed the same, or declined.
/// Auto-dismisses after [_autoDismissMs] milliseconds, or on tap.
class SetResultScreen extends StatefulWidget {
  final SetComparisonModel comparison;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double? weightKg;

  const SetResultScreen({
    super.key,
    required this.comparison,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    this.weightKg,
  });

  static Future<void> show(
    BuildContext context, {
    required SetComparisonModel comparison,
    required String exerciseName,
    required int setNumber,
    required int reps,
    double? weightKg,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => SetResultScreen(
          comparison: comparison,
          exerciseName: exerciseName,
          setNumber: setNumber,
          reps: reps,
          weightKg: weightKg,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<SetResultScreen> createState() => _SetResultScreenState();
}

class _SetResultScreenState extends State<SetResultScreen> with SingleTickerProviderStateMixin {
  static const int _autoDismissMs = 2500;
  late final AnimationController _progressCtrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: _autoDismissMs));
    _progressCtrl.forward();
    _timer = Timer(const Duration(milliseconds: _autoDismissMs), _dismiss);

    // Haptic feedback based on verdict
    if (widget.comparison.isImproved) {
      HapticFeedback.heavyImpact();
    } else if (widget.comparison.isDeclined) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final comp = widget.comparison;
    final config = _VerdictConfig.from(comp.verdict);

    return GestureDetector(
      onTap: _dismiss,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                // Dismiss progress bar
                AnimatedBuilder(
                  animation: _progressCtrl,
                  builder: (_, __) => LinearProgressIndicator(
                    value: 1 - _progressCtrl.value,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(config.color.withOpacity(0.6)),
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('tap anywhere to continue',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),

                const Spacer(),

                // Icon pulse
                _PulsingIcon(icon: config.icon, color: config.color),
                const SizedBox(height: 24),

                // Verdict headline
                Text(
                  config.headline,
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: config.color,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Motivational copy
                Text(
                  config.message,
                  style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Stats comparison card
                _ComparisonCard(comparison: comp, exerciseName: widget.exerciseName),

                const SizedBox(height: 24),

                // This set summary
                _ThisSetBadge(reps: widget.reps, weightKg: widget.weightKg, setNumber: widget.setNumber),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verdict config
// ---------------------------------------------------------------------------
class _VerdictConfig {
  final IconData icon;
  final Color color;
  final String headline;
  final String message;

  const _VerdictConfig({
    required this.icon,
    required this.color,
    required this.headline,
    required this.message,
  });

  factory _VerdictConfig.from(String verdict) {
    switch (verdict) {
      case 'improved':
        return const _VerdictConfig(
          icon: Icons.trending_up_rounded,
          color: Color(0xFF39E57A),
          headline: 'LEVEL UP! 🔥',
          message: 'You\'re getting stronger, Vivian!\nKeep pushing — graduation is going to be ICONIC.',
        );
      case 'declined':
        return const _VerdictConfig(
          icon: Icons.trending_down_rounded,
          color: Color(0xFFFFB547),
          headline: 'THAT\'S OK 💛',
          message: 'Every champion has off days.\nRest well, fuel right, come back stronger tomorrow!',
        );
      case 'same':
      default:
        return const _VerdictConfig(
          icon: Icons.trending_flat_rounded,
          color: Color(0xFF6ABAFF),
          headline: 'SOLID WORK! 💪',
          message: 'Consistency is the secret weapon.\nYou\'re right on track — keep showing up!',
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Pulsing icon
// ---------------------------------------------------------------------------
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(0.15),
          border: Border.all(color: widget.color.withOpacity(0.3), width: 2),
        ),
        child: Icon(widget.icon, size: 64, color: widget.color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats comparison card
// ---------------------------------------------------------------------------
class _ComparisonCard extends StatelessWidget {
  final SetComparisonModel comparison;
  final String exerciseName;
  const _ComparisonCard({required this.comparison, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final comp = comparison;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exerciseName.toUpperCase(),
              style: const TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 13,
                  color: Colors.white38,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'Prev. Reps',
                  value: '${comp.prevReps}',
                  change: comp.repsChange != 0
                      ? '${comp.repsChange > 0 ? '+' : ''}${comp.repsChange}'
                      : null,
                  positive: comp.repsChange >= 0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatColumn(
                  label: 'Prev. Weight',
                  value: comp.prevWeightKg > 0 ? '${comp.prevWeightKg.toStringAsFixed(1)} kg' : '—',
                  change: comp.weightChange != 0
                      ? '${comp.weightChange > 0 ? '+' : ''}${comp.weightChange.toStringAsFixed(1)} kg'
                      : null,
                  positive: comp.weightChange >= 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final bool positive;
  const _StatColumn({required this.label, required this.value, this.change, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontFamily: 'BarlowCondensed', fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
        if (change != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (positive ? const Color(0xFF39E57A) : const Color(0xFFFFB547)).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(change!,
                style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: positive ? const Color(0xFF39E57A) : const Color(0xFFFFB547))),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// This set badge
// ---------------------------------------------------------------------------
class _ThisSetBadge extends StatelessWidget {
  final int reps;
  final double? weightKg;
  final int setNumber;
  const _ThisSetBadge({required this.reps, this.weightKg, required this.setNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            'Set $setNumber: $reps reps${weightKg != null ? ' @ ${weightKg!.toStringAsFixed(1)} kg' : ''}',
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
