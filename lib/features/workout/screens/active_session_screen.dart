import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/rest_timer_provider.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';

/// The core workout tracking screen — set-by-set input with rest timer.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> with WidgetsBindingObserver {
  final _repsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(restTimerProvider.notifier).checkBackgroundReturn();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionNotifierProvider);
    final timer = ref.watch(restTimerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: sessionAsync.when(
        data: (session) {
          if (session == null || !session.isActive) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 64),
                  const SizedBox(height: 16),
                  Text('Workout Complete! 🎉',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontFamily: 'BarlowCondensed',
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('BACK TO HOME'),
                  ),
                ],
              ),
            );
          }
          return _buildSessionUI(context, session, timer);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Couldn\'t load session', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => context.go('/workout'), child: const Text('Back')),
          ]),
        ),
      ),
    );
  }

  Widget _buildSessionUI(BuildContext context, WorkoutSessionModel session, RestTimerState timer) {
    final nextSet = session.nextSet;

    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          backgroundColor: AppColors.background,
          pinned: true,
          title: Text(session.planName,
              style: const TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 22)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmCancel(context, session),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _confirmFinishEarly(context, session),
              icon: const Icon(Icons.check_rounded, color: AppColors.accent, size: 16),
              label: const Text('Finish', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            _WorkoutElapsedTimerBadge(startedAt: session.startedAt),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.list_rounded),
              onPressed: () => _showExerciseSidebar(context, session),
            ),
          ],
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Big Workout Activity Timer Card below header
              _BigWorkoutElapsedTimerCard(startedAt: session.startedAt),
              const SizedBox(height: 16),
              // Exercise progress overview
              _ExerciseProgressBar(session: session),
              const SizedBox(height: 24),

              if (nextSet != null && !timer.isRunning) ...[
                // Current set input
                _buildCurrentSetInput(context, session, nextSet),
              ] else if (timer.isRunning) ...[
                // Rest timer
                _buildRestTimer(context, session, timer),
              ] else ...[
                // Session complete — show summary
                _buildSessionComplete(context, session),
              ],

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSetInput(BuildContext context, WorkoutSessionModel session, SessionSetModel nextSet) {
    final exercise = session.exercises.firstWhere((e) => e.sets.contains(nextSet));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise name + set number
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.surfaceVariant],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('SET ${nextSet.setNumber}',
                        style: const TextStyle(
                            fontFamily: 'BarlowCondensed',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textOnPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Text('of ${exercise.totalSets}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              Text(nextSet.exerciseName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: 'BarlowCondensed',
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
              const SizedBox(height: 4),
              Text('${exercise.completedSets} of ${exercise.totalSets} sets done',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Reps + Weight input
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reps', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _repsCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 36, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weight (kg)', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 36, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Done button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isRecording ? null : () => _recordSet(context, session, nextSet),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            child: _isRecording
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                : const Text('✓  DONE — START REST'),
          ),
        ),

        const SizedBox(height: 12),

        // Skip exercise button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _skipExercise(context, session, nextSet.exerciseName),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('SKIP ${nextSet.exerciseName.toUpperCase()}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ),

        const SizedBox(height: 12),

        // Finish Workout Now Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmFinishEarly(context, session),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('FINISH WORKOUT NOW'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestTimer(BuildContext context, WorkoutSessionModel session, RestTimerState timer) {
    final mins = timer.remainingSeconds ~/ 60;
    final secs = timer.remainingSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Text('REST TIME', style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary, letterSpacing: 3)),
        const SizedBox(height: 20),

        // Circular timer
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(220, 220),
                painter: _TimerPainter(progress: timer.progress),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(timeStr,
                      style: const TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (timer.exerciseName != null)
                    Text('Next: ${timer.exerciseName}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // +/- buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TimerAdjustButton(
              label: '-15s',
              onTap: () => ref.read(restTimerProvider.notifier).adjustDuration(-15),
            ),
            const SizedBox(width: 16),
            _TimerAdjustButton(
              label: '+15s',
              onTap: () => ref.read(restTimerProvider.notifier).adjustDuration(15),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Skip rest button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(restTimerProvider.notifier).stop();
            },
            child: const Text('SKIP REST', style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 16, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionComplete(BuildContext context, WorkoutSessionModel session) {
    return Column(
      children: [
        const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 64),
        const SizedBox(height: 16),
        Text('All done! 🎉', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Great workout, Vivian! Let\'s wrap it up.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _completeSession(context, session),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('FINISH WORKOUT', style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.textOnPrimary)),
        ),
      ],
    );
  }

  Future<void> _recordSet(BuildContext context, WorkoutSessionModel session, SessionSetModel set) async {
    final reps = int.tryParse(_repsCtrl.text);
    if (reps == null || reps < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter how many reps you did!')),
      );
      return;
    }
    final weightKg = double.tryParse(_weightCtrl.text);
    setState(() => _isRecording = true);

    try {
      HapticFeedback.mediumImpact();
      await ref.read(activeSessionNotifierProvider.notifier).recordSet(
        session.id,
        set.id,
        reps: reps,
        weightKg: weightKg,
      );

      _repsCtrl.clear();
      // Keep weight for next set convenience

      // Start rest timer
      final nextSet = ref.read(activeSessionNotifierProvider).value?.nextSet;
      ref.read(restTimerProvider.notifier).start(
        exerciseName: nextSet?.exerciseName ?? set.exerciseName,
        nextSetNumber: nextSet?.setNumber,
      );
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _skipExercise(BuildContext context, WorkoutSessionModel session, String exerciseName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Skip Exercise?'),
        content: Text('Skip $exerciseName for now? You can come back to it at the end if you want.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      await ref.read(activeSessionNotifierProvider.notifier).skipExercise(session.id, exerciseName);
    }
  }

  Future<void> _completeSession(BuildContext context, WorkoutSessionModel session) async {
    // Check for skipped exercises
    final skipped = await ref.read(activeSessionNotifierProvider.notifier).getSkippedExercises(session.id);
    if (!mounted) return;

    if (skipped.isNotEmpty) {
      // Ask about skipped exercises
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetCtx) => _SkippedExercisesSheet(
          skippedNames: skipped,
          sessionId: session.id,
          onDone: () async {
            Navigator.pop(sheetCtx);
            if (context.mounted) await _finishSession(context, session);
          },
        ),
      );
    } else {
      if (context.mounted) await _finishSession(context, session);
    }
  }

  Future<void> _confirmFinishEarly(BuildContext context, WorkoutSessionModel session) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Finish Workout Now?'),
        content: const Text('Do you want to complete and log this workout session now, even with remaining exercises left?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Finish Now'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await _finishSession(context, session);
    }
  }

  Future<void> _finishSession(BuildContext context, WorkoutSessionModel session) async {
    try {
      HapticFeedback.heavyImpact();
      await ref.read(activeSessionNotifierProvider.notifier).completeSession(session.id);
      ref.read(restTimerProvider.notifier).stop();
      if (context.mounted) context.go('/workout');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not finish session. Try again!')),
        );
      }
    }
  }

  Future<void> _confirmCancel(BuildContext context, WorkoutSessionModel session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('End Workout?'),
        content: const Text('Are you sure you want to stop this workout? Your progress won\'t be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Going')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Stop Workout'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(activeSessionNotifierProvider.notifier).cancelSession(session.id);
      ref.read(restTimerProvider.notifier).stop();
      if (context.mounted) context.go('/workout');
    }
  }

  void _showExerciseSidebar(BuildContext context, WorkoutSessionModel session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExerciseSidebar(session: session),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise progress bar
// ---------------------------------------------------------------------------
class _ExerciseProgressBar extends StatelessWidget {
  final WorkoutSessionModel session;
  const _ExerciseProgressBar({required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(session.planName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text('${session.exercises.where((e) => e.isAllCompleted).length}/${session.exercises.length} exercises',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: session.exercises.map((ex) {
              Color color;
              if (ex.isSkipped) color = AppColors.statusSkipped;
              else if (ex.isAllCompleted) color = AppColors.statusCompleted;
              else color = AppColors.statusPending;

              return Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  ex.exerciseName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Timer painter
// ---------------------------------------------------------------------------
class _TimerPainter extends CustomPainter {
  final double progress;
  const _TimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background circle
    canvas.drawCircle(center, radius, Paint()..color = AppColors.surfaceVariant);

    // Progress arc
    final sweepAngle = -2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      Paint()
        ..color = progress < 0.25 ? AppColors.error : AppColors.primary
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TimerPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// Timer adjust button
// ---------------------------------------------------------------------------
class _TimerAdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TimerAdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise sidebar (list of all exercises with status)
// ---------------------------------------------------------------------------
class _ExerciseSidebar extends StatelessWidget {
  final WorkoutSessionModel session;
  const _ExerciseSidebar({required this.session});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exercises', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...session.exercises.map((ex) {
            Color color;
            IconData icon;
            String status;
            if (ex.isSkipped) { color = AppColors.statusSkipped; icon = Icons.skip_next_rounded; status = 'Skipped'; }
            else if (ex.isAllCompleted) { color = AppColors.statusCompleted; icon = Icons.check_circle_rounded; status = '${ex.completedSets}/${ex.totalSets} sets'; }
            else { color = AppColors.statusPending; icon = Icons.radio_button_unchecked_rounded; status = '${ex.completedSets}/${ex.totalSets} sets'; }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(ex.exerciseName, style: Theme.of(context).textTheme.bodyMedium)),
                Text(status, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
              ]),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skipped exercises bottom sheet (end of session)
// ---------------------------------------------------------------------------
class _SkippedExercisesSheet extends ConsumerWidget {
  final List<String> skippedNames;
  final String sessionId;
  final VoidCallback onDone;

  const _SkippedExercisesSheet({
    required this.skippedNames,
    required this.sessionId,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You skipped some exercises!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Want to go back and do any of these?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ...skippedNames.map((name) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.skip_next_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(name, style: Theme.of(context).textTheme.bodyMedium)),
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(activeSessionNotifierProvider.notifier).reEnableExercise(sessionId, name);
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent),
                        minimumSize: const Size(90, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('DO IT NOW'),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('FINISH ANYWAY',
                  style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textOnPrimary)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ongoing Activity Elapsed Stopwatch Ticker
// ---------------------------------------------------------------------------
class _WorkoutElapsedTimerBadge extends StatefulWidget {
  final DateTime startedAt;
  const _WorkoutElapsedTimerBadge({required this.startedAt});

  @override
  State<_WorkoutElapsedTimerBadge> createState() => _WorkoutElapsedTimerBadgeState();
}

class _WorkoutElapsedTimerBadgeState extends State<_WorkoutElapsedTimerBadge> {
  Timer? _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
  }

  void _updateElapsed() {
    if (mounted) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.startedAt);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours;
    final mins = _elapsed.inMinutes.remainder(60);
    final secs = _elapsed.inSeconds.remainder(60);

    final timeStr = hours > 0
        ? '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
        : '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.primary, size: 14),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 13,
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

// ---------------------------------------------------------------------------
// Big Workout Activity Timer Card below header
// ---------------------------------------------------------------------------
class _BigWorkoutElapsedTimerCard extends StatefulWidget {
  final DateTime startedAt;
  const _BigWorkoutElapsedTimerCard({required this.startedAt});

  @override
  State<_BigWorkoutElapsedTimerCard> createState() => _BigWorkoutElapsedTimerCardState();
}

class _BigWorkoutElapsedTimerCardState extends State<_BigWorkoutElapsedTimerCard> {
  Timer? _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
  }

  void _updateElapsed() {
    if (mounted) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.startedAt);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours;
    final mins = _elapsed.inMinutes.remainder(60);
    final secs = _elapsed.inSeconds.remainder(60);

    final timeStr = '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'WORKOUT ELAPSED TIME',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.timer_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

