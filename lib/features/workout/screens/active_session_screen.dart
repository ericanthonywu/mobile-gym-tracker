import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/master_activity_model.dart';
import 'package:gym_tracker/features/workout/models/set_comparison_model.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/master_activity_provider.dart';
import 'package:gym_tracker/features/workout/providers/rest_timer_provider.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:gym_tracker/features/workout/widgets/exercise_form_preview.dart';


/// Phase of the current set: actively performing the exercise, or logging results.
enum _SetPhase { executing, logging, resting }

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

  // ── Set phase state machine ──
  // executing = showing the big timer while the user does the exercise
  // logging   = showing the reps/weight input form (during rest)
  _SetPhase _setPhase = _SetPhase.executing;

  // ── In-set stopwatch for time-based activities ──
  int _setTimerSeconds = 0;
  bool _setTimerRunning = false;
  Timer? _setTimer;
  String? _activeSetId; // tracks which set is currently displayed

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
    _setTimer?.cancel();
    super.dispose();
  }

  void _resetSetTimer() {
    _setTimer?.cancel();
    setState(() {
      _setTimerSeconds = 0;
      _setTimerRunning = false;
    });
  }

  void _startSetTimer() {
    if (_setTimerRunning) return;
    _setTimer?.cancel();
    _setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _setTimerSeconds++);
    });
    setState(() {
      _setTimerRunning = true;
    });
  }

  void _stopSetTimer() {
    _setTimer?.cancel();
    if (mounted) setState(() {
      _setTimerRunning = false;
    });
  }

  /// Called when the displayed set changes. Resets and auto-starts for time-based sets.
  void _onSetActivated(SessionSetModel set) {
    _setTimer?.cancel();
    _setTimerSeconds = 0;
    _setTimerRunning = false;
    _activeSetId = set.id;
    if (set.isTimeBased) {
      // Time-based: auto-start immediately — user shouldn't tap a button mid-plank
      // Stay in executing phase, the timer IS the exercise
      _setPhase = _SetPhase.executing;
      _setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _setTimerSeconds++);
      });
      _setTimerRunning = true;
    } else {
      // Reps-based: start with executing phase (big execution timer)
      _setPhase = _SetPhase.executing;
      // Pre-fill smart defaults from last session when set is activated
      if (set.defaultReps != null) {
        _repsCtrl.text = set.defaultReps!.toString();
      } else {
        _repsCtrl.clear();
      }
      if (set.defaultWeightKg != null) {
        _weightCtrl.text = set.defaultWeightKg!.toStringAsFixed(1);
      } else {
        _weightCtrl.clear();
      }
      // Start execution stopwatch automatically
      _setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _setTimerSeconds++);
      });
      _setTimerRunning = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionNotifierProvider);
    final timer = ref.watch(restTimerProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildSessionUI(BuildContext context, WorkoutSessionModel session, RestTimerState timer) {
    final nextSet = session.nextSet;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: () async {
        await ref.read(activeSessionNotifierProvider.notifier).load();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
              icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
              onPressed: () => _showExerciseManager(context, session),
              tooltip: 'Manage exercises',
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

              // ── 3-Phase State Machine ──
              if (nextSet == null && !timer.isActive) ...[
                // Session complete — all sets done
                _buildSessionComplete(context, session),
              ] else if (_setPhase == _SetPhase.executing && nextSet != null) ...[
                // Phase 1: Executing — stopwatch while doing the exercise
                if (nextSet.isTimeBased)
                  _buildTimeSetInput(context, session, nextSet, session.exercises.firstWhere((e) => e.sets.contains(nextSet)))
                else
                  _buildSetExecutionView(context, session, nextSet),
              ] else if (_setPhase == _SetPhase.logging && nextSet != null) ...[
                // Phase 2: Logging — reps/weight input only (rest timer running in background)
                _buildLogRepsView(context, session, nextSet),
              ] else if (_setPhase == _SetPhase.resting || timer.isActive) ...[
                // Phase 3: Resting — countdown timer only (no input form)
                _buildRestView(context, session, timer),
              ] else if (nextSet != null) ...[
                // Fallback: show execution view
                if (nextSet.isTimeBased)
                  _buildTimeSetInput(context, session, nextSet, session.exercises.firstWhere((e) => e.sets.contains(nextSet)))
                else
                  _buildSetExecutionView(context, session, nextSet),
              ],

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    ),
  );
  }

  // ── NEW: Set Execution View (Phase 1 — doing the exercise) ──
  // Shown for reps-based sets before the user logs their reps.
  // Features a big count-up stopwatch so the user can time their set.
  // Tapping DONE starts the rest timer and switches to the logging phase.
  Widget _buildSetExecutionView(BuildContext context, WorkoutSessionModel session, SessionSetModel nextSet) {
    final exercise = session.exercises.firstWhere((e) => e.sets.contains(nextSet));

    // Activate this set on first render
    if (_activeSetId != nextSet.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSetActivated(nextSet);
      });
    }

    final elapsed = _setTimerSeconds;
    final timeStr = _formatDuration(elapsed);

    // Determine timer color based on elapsed time
    const Color activeColor = Color(0xFF4CAF50);
    const Color warmColor = Color(0xFFF97316);
    final Color timerColor = elapsed > 60 ? warmColor : activeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exercise header
        _buildExerciseHeader(context, nextSet, exercise, null),
        const SizedBox(height: 32),

        // ── Big execution timer display ──
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glowing outer ring
              AnimatedBuilder(
                animation: AlwaysStoppedAnimation(0),
                builder: (_, __) => Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: timerColor.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: timerColor.withOpacity(0.12),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              // Inner dark circle
              Container(
                width: 196,
                height: 196,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      timerColor.withOpacity(0.12),
                      AppColors.surfaceCard,
                    ],
                    radius: 0.9,
                  ),
                  border: Border.all(color: timerColor.withOpacity(0.35), width: 2),
                ),
              ),
              // Timer text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SET ${nextSet.setNumber} of ${exercise.totalSets}',
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: timerColor.withOpacity(0.7),
                      letterSpacing: 2,
                    ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: timerColor,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(color: timerColor.withOpacity(0.4), blurRadius: 20),
                      ],
                    ),
                    child: Text(timeStr),
                  ),
                  Text(
                    elapsed == 0 ? 'GO!' : 'elapsed',
                    style: TextStyle(
                      fontSize: 12,
                      color: timerColor.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Hint text
        Center(
          child: Text(
            _setTimerRunning
                ? 'Timer running — focus on your ${nextSet.exerciseName}!'
                : 'Tap PAUSE to stop the timer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textDisabled,
                  fontStyle: FontStyle.italic,
                ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 8),

        // Pause/Resume timer controls
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_setTimerRunning)
                OutlinedButton.icon(
                  onPressed: _stopSetTimer,
                  icon: const Icon(Icons.pause_rounded, size: 18),
                  label: const Text('PAUSE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _startSetTimer,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('RESUME'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _resetSetTimer,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('RESET'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── I'M DONE button — starts rest timer in background + transitions to logging phase ──
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              FocusScope.of(context).unfocus();
              _stopSetTimer();
              // Start rest timer immediately in background (UI not shown yet)
              final ex = exercise;
              ref.read(restTimerProvider.notifier).start(
                exerciseName: nextSet.exerciseName,
                nextSetNumber: nextSet.setNumber,
                totalSets: ex.totalSets,
              );
              // Pre-fill smart defaults for the logging form
              if (nextSet.defaultReps != null) {
                _repsCtrl.text = nextSet.defaultReps!.toString();
              } else {
                _repsCtrl.clear();
              }
              if (nextSet.defaultWeightKg != null) {
                _weightCtrl.text = nextSet.defaultWeightKg!.toStringAsFixed(1);
              } else {
                _weightCtrl.clear();
              }
              setState(() => _setPhase = _SetPhase.logging);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 22),
                SizedBox(width: 10),
                Text("I'M DONE"),
              ],
            ),
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
      ],
    );
  }

  // ── NEW: Dedicated Log Reps View (Phase 2 — logging only, no timer UI) ──
  // Rest timer is already running in the background since the user tapped "I'M DONE".
  // This view shows ONLY the reps/weight input form for a clean, focused experience.
  Widget _buildLogRepsView(BuildContext context, WorkoutSessionModel session, SessionSetModel nextSet) {
    final exercise = session.exercises.firstWhere((e) => e.sets.contains(nextSet));

    final hasDefaults = nextSet.defaultReps != null || nextSet.defaultWeightKg != null;
    final defaultHint = hasDefaults
        ? 'Last time: ${nextSet.defaultReps != null ? '${nextSet.defaultReps} reps' : ''}'
            '${nextSet.defaultReps != null && nextSet.defaultWeightKg != null ? ' @ ' : ''}'
            '${nextSet.defaultWeightKg != null ? '${nextSet.defaultWeightKg!.toStringAsFixed(1)} kg' : ''}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise name + set number header card
        _buildExerciseHeader(context, nextSet, exercise, defaultHint),

        const SizedBox(height: 8),

        // Phase indicator
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'LOG YOUR REPS',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
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
                    autofocus: true,
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
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 36, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // SAVE SET button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isRecording ? null : () => _recordSet(context, session, nextSet),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.5),
              elevation: 0,
            ),
            child: _isRecording
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 22),
                      SizedBox(width: 10),
                      Text('SAVE SET'),
                    ],
                  ),
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
      ],
    );
  }

  // ── Shared exercise header card ──
  Widget _buildExerciseHeader(BuildContext context, SessionSetModel nextSet, ExerciseSessionModel exercise, String? hint) {
    // Look up the full activity model from the cached list for image preview
    final allActivities = ref.watch(masterActivitiesProvider).value ?? [];
    final matchedActivity = allActivities
        .cast<MasterActivityModel?>()
        .firstWhere(
          (a) => a!.name.toLowerCase() == nextSet.exerciseName.toLowerCase(),
          orElse: () => null,
        );

    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('SET ${nextSet.setNumber} of ${exercise.totalSets}',
                          style: const TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textOnPrimary)),
                    ),
                    const SizedBox(height: 10),
                    Text(nextSet.exerciseName,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontFamily: 'BarlowCondensed',
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                    if (hint != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.history_rounded, size: 12, color: AppColors.textDisabled),
                        const SizedBox(width: 4),
                        Text(hint,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textDisabled, fontStyle: FontStyle.italic)),
                      ]),
                    ],
                  ],
                ),
              ),
              // Eye icon to preview form
              if (matchedActivity != null && matchedActivity.hasFormImage)
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_rounded, color: AppColors.primary, size: 22),
                  tooltip: 'View form',
                  onPressed: () => showExerciseFormPreview(context, matchedActivity),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          // Inline form images shown during execution phase (start & finish)
          if (matchedActivity != null && matchedActivity.hasFormImage) ...[
            const SizedBox(height: 12),
            ExerciseFormImages(
              key: ValueKey(matchedActivity.id),
              activity: matchedActivity,
              height: 150,
            ),
          ],
        ],
      ),
    );
  }

  // ── Time-based set input: count-up stopwatch with milestone states ──
  Widget _buildTimeSetInput(BuildContext context, WorkoutSessionModel session, SessionSetModel nextSet, ExerciseSessionModel exercise) {
    // Activate this set on first render (starts the count-up timer automatically)
    if (_activeSetId != nextSet.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSetActivated(nextSet);
      });
    }

    final targetSecs = nextSet.defaultDurationSeconds; // last session's duration (used as goal)
    final lastRecord = nextSet.defaultDurationSeconds;
    // top record is not directly in the model — we derive milestone states from what we know
    final elapsed = _setTimerSeconds;

    // ── Milestone state machine ──
    // State 1 (green):  elapsed < target (or no target)
    // State 2 (yellow): elapsed >= target (passed goal) but < lastRecord (if exists)
    // State 3 (orange): elapsed >= lastRecord (beating last session record)
    // We don't know the top record until after save, but we track it via comparison in the result screen
    final bool pastTarget = targetSecs != null && elapsed >= targetSecs;
    final bool pastLastRecord = lastRecord != null && elapsed > lastRecord;

    Color timerColor;
    String? motivationalCopy;
    bool isPulsing = false;

    if (pastLastRecord) {
      timerColor = const Color(0xFFFF8C00); // orange-gold — beating last record
      motivationalCopy = "🔥 You're beating your last record! Keep pushing!";
      isPulsing = true;
    } else if (pastTarget) {
      timerColor = const Color(0xFFFFD700); // yellow — past goal
      motivationalCopy = '💪 Keep going — you\'re past your goal!';
    } else {
      timerColor = const Color(0xFF4CAF50); // green
      motivationalCopy = targetSecs != null
          ? 'Hold for ${_formatDuration(targetSecs)}'
          : null;
    }

    final timeStr = _formatDuration(elapsed);

    final recordLine = lastRecord != null
        ? 'Last: ${_formatDuration(lastRecord)}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise header
        _buildExerciseHeader(context, nextSet, exercise, recordLine),

        const SizedBox(height: 24),

        // Stopwatch display
        Center(
          child: Column(
            children: [
              // Big animated timer
              _PulsingTimerDisplay(
                timeStr: timeStr,
                color: timerColor,
                isPulsing: isPulsing && _setTimerRunning,
              ),

              const SizedBox(height: 8),

              // Motivational copy
              if (motivationalCopy != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    motivationalCopy,
                    key: ValueKey(motivationalCopy),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: timerColor,
                      fontWeight: pastLastRecord ? FontWeight.w800 : FontWeight.w600,
                      fontSize: pastLastRecord ? 15 : 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Timer controls: auto-started, so show PAUSE or RESUME+RESET
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_setTimerRunning)
                    OutlinedButton.icon(
                      onPressed: _stopSetTimer,
                      icon: const Icon(Icons.pause_rounded, size: 22),
                      label: const Text('PAUSE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: timerColor,
                        side: BorderSide(color: timerColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    )
                  else ...[
                    ElevatedButton.icon(
                      onPressed: _startSetTimer,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text('RESUME'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: timerColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _resetSetTimer,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('RESET'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Done button — elapsed > 0 required
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isRecording || elapsed == 0) ? null : () => _recordSet(context, session, nextSet),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            child: _isRecording
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                : Text('✓  DONE — SAVE ${_formatDuration(elapsed)}'),
          ),
        ),

        const SizedBox(height: 12),

        // Skip button
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

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    FocusScope.of(context).unfocus();
    if (set.isTimeBased) {
      // Time-based: stop the timer and save duration
      _stopSetTimer();
      if (_setTimerSeconds == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start the timer first!')),
        );
        return;
      }
      setState(() => _isRecording = true);
      try {
        HapticFeedback.mediumImpact();
        final comparison = await ref.read(activeSessionNotifierProvider.notifier).recordSet(
          session.id,
          set.id,
          durationSeconds: _setTimerSeconds,
        );

        // Show a special time result overlay
        if (comparison != null && mounted) {
          await _showTimeResult(context, comparison, set, _setTimerSeconds);
        }

        _resetSetTimer();
        _activeSetId = null;

        // Start rest timer
        final updatedSession = ref.read(activeSessionNotifierProvider).value;
        int? totalSets;
        if (updatedSession != null) {
          final ex = updatedSession.exercises.firstWhere(
            (e) => e.exerciseName == set.exerciseName,
            orElse: () => updatedSession.exercises.first,
          );
          totalSets = ex.totalSets;
        }
        ref.read(restTimerProvider.notifier).start(
          exerciseName: set.exerciseName,
          nextSetNumber: set.setNumber,
          totalSets: totalSets,
        );
      } finally {
        if (mounted) setState(() => _isRecording = false);
      }
      return;
    }

    // ── Reps-based ──
    final reps = int.tryParse(_repsCtrl.text);
    if (reps == null || reps < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter how many reps you did!')),
      );
      return;
    }
    // Normalize comma → dot before parsing
    final weightText = _weightCtrl.text.replaceAll(',', '.');
    final weightKg = double.tryParse(weightText);
    setState(() => _isRecording = true);

    try {
      HapticFeedback.mediumImpact();
      final comparison = await ref.read(activeSessionNotifierProvider.notifier).recordSet(
        session.id,
        set.id,
        reps: reps,
        weightKg: weightKg,
      );

      _repsCtrl.clear();
      // Keep weight for next set convenience

      // Show inline snackbar with comparison feedback (replaces full-screen SetResultScreen)
      if (mounted) {
        String feedbackMsg;
        if (comparison != null) {
          switch (comparison.verdict) {
            case 'improved':
              feedbackMsg = '🔥 Set ${set.setNumber} saved — you improved!';
              break;
            case 'declined':
              feedbackMsg = '💪 Set ${set.setNumber} saved — keep pushing!';
              break;
            default:
              feedbackMsg = '✓ Set ${set.setNumber} saved — $reps reps${weightKg != null ? ' @ ${weightKg.toStringAsFixed(1)} kg' : ''}';
          }
        } else {
          feedbackMsg = '✓ Set ${set.setNumber} saved — $reps reps${weightKg != null ? ' @ ${weightKg.toStringAsFixed(1)} kg' : ''}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackMsg, style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.surfaceCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Transition to resting phase (rest timer is already running since "I'M DONE")
      _activeSetId = null;
      if (mounted) setState(() => _setPhase = _SetPhase.resting);
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _showTimeResult(BuildContext context, SetComparisonModel comparison, SessionSetModel set, int durationSeconds) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TimeSetResultSheet(
        comparison: comparison,
        exerciseName: set.exerciseName,
        setNumber: set.setNumber,
        durationSeconds: durationSeconds,
      ),
    );
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
      if (context.mounted) context.go('/workout?tab=2');
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

  /// Mid-session: show the unified exercise manager sheet (reorder + add + edit + delete).
  void _showExerciseManager(BuildContext context, WorkoutSessionModel session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExerciseManagerSheet(session: session),
    );
  }

  // ── NEW: Dedicated Rest View (Phase 3 — countdown timer only, no input form) ──
  // The rest timer was started in background when user tapped "I'M DONE" (Step 1 → Step 2).
  // Now we show the countdown UI. If the user logged reps quickly, they'll see remaining time.
  // If they took long, rest may already be over.
  Widget _buildRestView(BuildContext context, WorkoutSessionModel session, RestTimerState timer) {
    if (timer.isRestOver || !timer.isActive) {
      // Rest is over — show "start next set" prompt
      return Column(
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alarm_on_rounded, color: AppColors.accent, size: 64),
          ),
          const SizedBox(height: 20),
          Text(
            'REST TIME OVER!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            timer.exerciseName != null
                ? 'Ready for ${timer.exerciseName}?'
                : 'Ready for your next set?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (timer.nextSetNumber != null) ...[
            const SizedBox(height: 12),
            // Current (completed) set
            Text(
              timer.totalSets != null
                  ? 'SET ${timer.nextSetNumber} of ${timer.totalSets}'
                  : 'SET ${timer.nextSetNumber}',
              style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            // Next upcoming set — or next exercise if this was the last set
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Next: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (timer.totalSets != null && timer.nextSetNumber! >= timer.totalSets!)
                      ? (timer.exerciseName != null ? 'SET 1 · ${timer.exerciseName}' : 'Next Exercise')
                      : (timer.totalSets != null
                          ? 'SET ${timer.nextSetNumber! + 1} of ${timer.totalSets}'
                          : 'SET ${timer.nextSetNumber! + 1}'),
                  style: const TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.accent,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(restTimerProvider.notifier).stop();
                setState(() => _setPhase = _SetPhase.executing);
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: const Text('START NEXT SET'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () { HapticFeedback.lightImpact(); ref.read(restTimerProvider.notifier).extendRest(15); setState(() {}); },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('+15s Rest', style: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () { HapticFeedback.lightImpact(); ref.read(restTimerProvider.notifier).extendRest(30); setState(() {}); },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('+30s Rest', style: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Active rest countdown — Big Prominent Circular Rest Stopwatch (no input form)
    final mins = timer.remainingSeconds ~/ 60;
    final secs = timer.remainingSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Column(
      children: [
        const SizedBox(height: 8),

        // Phase indicator
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bedtime_rounded, size: 16, color: AppColors.primary.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(
                  'RESTING',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary.withOpacity(0.7),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Big Circular Rest Countdown Stopwatch ──
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'REST TIMER',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 20),

              // Large 200x200 Circular Timer Ring
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: _TimerPainter(progress: timer.progress),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontFamily: 'BarlowCondensed',
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1,
                          ),
                        ),
                        if (timer.nextSetNumber != null) ...[
                          const SizedBox(height: 4),
                          // Current (completed) set
                          Text(
                            timer.totalSets != null
                                ? 'SET ${timer.nextSetNumber} of ${timer.totalSets}'
                                : 'SET ${timer.nextSetNumber}',
                            style: const TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Next upcoming set — or next exercise if this was the last set
                          Text(
                            (timer.totalSets != null && timer.nextSetNumber! >= timer.totalSets!)
                                ? (timer.exerciseName != null
                                    ? 'Next: SET 1 · ${timer.exerciseName}'
                                    : 'Next: Next Exercise')
                                : (timer.totalSets != null
                                    ? 'Next: SET ${timer.nextSetNumber! + 1} of ${timer.totalSets}'
                                    : 'Next: SET ${timer.nextSetNumber! + 1}'),
                            style: const TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            timer.exerciseName != null
                                ? 'Next: ${timer.exerciseName}'
                                : 'Rest',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: AppColors.textSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Controls: Adjust time & Skip Rest
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimerAdjustButton(
                    label: '-15s',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(restTimerProvider.notifier).adjustDuration(-15);
                    },
                  ),
                  const SizedBox(width: 12),
                  _TimerAdjustButton(
                    label: '+15s',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(restTimerProvider.notifier).adjustDuration(15);
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(restTimerProvider.notifier).stop();
                      setState(() => _setPhase = _SetPhase.executing);
                    },
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text('SKIP REST'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
// Unified Exercise Manager Sheet
// Combines: view list, reorder, add new, edit sets/reps, delete
// ---------------------------------------------------------------------------
enum _ManagerView { list, add, edit }

class _ExerciseManagerSheet extends ConsumerStatefulWidget {
  final WorkoutSessionModel session;
  const _ExerciseManagerSheet({required this.session});

  @override
  ConsumerState<_ExerciseManagerSheet> createState() => _ExerciseManagerSheetState();
}

class _ExerciseManagerSheetState extends ConsumerState<_ExerciseManagerSheet> {
  late List<ExerciseSessionModel> _exercises;
  _ManagerView _view = _ManagerView.list;

  // For Add view
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedMuscle;
  String? _selectedCategory;
  MasterActivityModel? _selectedActivity;
  String? _selectedName;
  String _addActivityType = 'reps';
  int _addSets = 3;
  int _addReps = 12;
  int _addDuration = 60;
  bool _isAdding = false;

  // For Edit view
  ExerciseSessionModel? _editTarget;
  int _editSets = 3;
  int _editReps = 12;
  String _editActivityType = 'reps';
  int _editDuration = 60;
  bool _isSavingEdit = false;

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.session.exercises);
  }

  @override
  void didUpdateWidget(covariant _ExerciseManagerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _exercises = List.from(widget.session.exercises);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
    final names = _exercises.map((e) => e.exerciseName).toList();
    ref.read(activeSessionNotifierProvider.notifier).reorderExercises(widget.session.id, names);
  }

  Future<void> _removeExercise(ExerciseSessionModel ex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Remove ${ex.exerciseName}?',
            style: const TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
        content: Text(
          ex.completedSets > 0
              ? 'This will remove the ${ex.totalSets - ex.completedSets} remaining sets. The ${ex.completedSets} completed set${ex.completedSets > 1 ? 's' : ''} will be preserved.'
              : 'This will remove all ${ex.totalSets} sets from your workout.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(activeSessionNotifierProvider.notifier).removeExercise(widget.session.id, ex.exerciseName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${ex.exerciseName} removed'),
          backgroundColor: AppColors.surfaceCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        // Refresh exercise list
        final session = ref.read(activeSessionNotifierProvider).value;
        if (session != null) setState(() => _exercises = List.from(session.exercises));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not remove: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _startEdit(ExerciseSessionModel ex) {
    setState(() {
      _editTarget = ex;
      _editSets = ex.totalSets;
      _editReps = ex.sets.isNotEmpty ? (ex.sets.first.defaultReps ?? 12) : 12;
      _editActivityType = ex.sets.isNotEmpty ? ex.sets.first.activityType : 'reps';
      _editDuration = ex.sets.isNotEmpty ? (ex.sets.first.defaultDurationSeconds ?? 60) : 60;
      _view = _ManagerView.edit;
    });
  }

  Future<void> _saveEdit() async {
    if (_editTarget == null) return;
    setState(() => _isSavingEdit = true);
    try {
      await ref.read(activeSessionNotifierProvider.notifier).editExercise(
        widget.session.id,
        exerciseName: _editTarget!.exerciseName,
        targetSets: _editSets,
        targetReps: _editActivityType == 'reps' ? _editReps : 0,
        activityType: _editActivityType,
        targetDurationSeconds: _editActivityType == 'time' ? _editDuration : null,
      );
      HapticFeedback.lightImpact();
      if (mounted) {
        final session = ref.read(activeSessionNotifierProvider).value;
        if (session != null) setState(() => _exercises = List.from(session.exercises));
        setState(() { _view = _ManagerView.list; _editTarget = null; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSavingEdit = false);
    }
  }

  Future<void> _addExercise() async {
    if (_selectedName == null) return;
    setState(() => _isAdding = true);
    try {
      await ref.read(activeSessionNotifierProvider.notifier).addExercise(
        widget.session.id,
        name: _selectedName!,
        targetSets: _addSets,
        targetReps: _addActivityType == 'reps' ? _addReps : 0,
        activityType: _addActivityType,
        targetDurationSeconds: _addActivityType == 'time' ? _addDuration : null,
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        final session = ref.read(activeSessionNotifierProvider).value;
        if (session != null) setState(() => _exercises = List.from(session.exercises));
        setState(() {
          _view = _ManagerView.list;
          _selectedName = null;
          _searchCtrl.clear();
          _query = '';
          _selectedMuscle = null;
          _selectedCategory = null;
          _selectedActivity = null;
          _isAdding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$_selectedName added to workout! 💪'),
          backgroundColor: AppColors.surfaceCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        if (_view == _ManagerView.add) return _buildAddView(context, scrollCtrl);
        if (_view == _ManagerView.edit && _editTarget != null) return _buildEditView(context, scrollCtrl);
        return _buildListView(context, scrollCtrl);
      },
    );
  }

  // ── List View ──────────────────────────────────────────────────────────────
  Widget _buildListView(BuildContext context, ScrollController scrollCtrl) {
    return Column(
      children: [
        // Handle + Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Exercises (${_exercises.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text('Drag ☰ to reorder',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(height: 12),
            ],
          ),
        ),

        // Exercise list
        Flexible(
          child: _exercises.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No exercises yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  ),
                )
              : ReorderableListView.builder(
                  scrollController: scrollCtrl,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _exercises.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final ex = _exercises[index];
                    final bool allDone = ex.isAllCompleted || ex.isSkipped;
                    final Color statusColor = ex.isSkipped
                        ? AppColors.statusSkipped
                        : ex.isAllCompleted
                            ? AppColors.statusCompleted
                            : AppColors.statusPending;
                    final IconData statusIcon = ex.isSkipped
                        ? Icons.skip_next_rounded
                        : ex.isAllCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded;
                    final String statusLabel = ex.isSkipped
                        ? 'Skipped'
                        : '${ex.completedSets}/${ex.totalSets} sets';

                    return Container(
                      key: ValueKey(ex.exerciseName),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          // Drag handle
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                              child: Icon(Icons.drag_handle_rounded, color: AppColors.textSecondary, size: 22),
                            ),
                          ),
                          // Status icon
                          Icon(statusIcon, color: statusColor, size: 18),
                          const SizedBox(width: 10),
                          // Name + status
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ex.exerciseName,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text(statusLabel,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor)),
                              ],
                            ),
                          ),
                          // Edit button (disabled if all done)
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                size: 20,
                                color: allDone ? AppColors.textDisabled : AppColors.textSecondary),
                            onPressed: allDone ? null : () => _startEdit(ex),
                            tooltip: allDone ? 'Cannot edit completed exercise' : 'Edit',
                          ),
                          // Delete button (disabled if all completed)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: ex.isAllCompleted ? AppColors.textDisabled : AppColors.error.withValues(alpha: 0.7),
                            ),
                            onPressed: ex.isAllCompleted ? null : () => _removeExercise(ex),
                            tooltip: ex.isAllCompleted ? 'Cannot delete fully completed exercise' : 'Remove',
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Add exercise button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() { _view = _ManagerView.add; _selectedName = null; _selectedActivity = null; _searchCtrl.clear(); _query = ''; _selectedMuscle = null; _selectedCategory = null; }),
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              label: const Text('ADD EXERCISE',
                  style: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Add View ───────────────────────────────────────────────────────────────
  Widget _buildAddView(BuildContext context, ScrollController scrollCtrl) {
    final muscles = ref.watch(activityMusclesProvider);
    final categories = ref.watch(activityCategoriesProvider);
    final searchResults = ref.watch(
      activitySearchProvider((
        query: _query,
        muscle: _selectedMuscle,
        category: _selectedCategory,
      )),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => setState(() { _view = _ManagerView.list; _selectedName = null; }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  Text('Add Exercise',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                autofocus: _selectedName == null,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search or type exercise name…',
                  hintStyle: const TextStyle(color: AppColors.textDisabled),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 8),
              // ── Category filter chips ──
              categories.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  final options = list.map((c) => c['category'] as String).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CATEGORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textDisabled, letterSpacing: 1.4)),
                      const SizedBox(height: 4),
                      _MuscleFilterChips(
                        selected: _selectedCategory,
                        muscles: options,
                        onChanged: (c) => setState(() => _selectedCategory = c),
                      ),
                      const SizedBox(height: 8),
                      const Text('MUSCLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textDisabled, letterSpacing: 1.4)),
                      const SizedBox(height: 4),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              // ── Muscle filter chips ──
              muscles.when(
                data: (list) {
                  final options = list.map((m) => m['muscle_name'] as String).toList();
                  return _MuscleFilterChips(
                    selected: _selectedMuscle,
                    muscles: options,
                    onChanged: (m) => setState(() => _selectedMuscle = m),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        if (_selectedName != null)
          _buildAddConfig(context)
        else
          Expanded(
            child: searchResults.when(
              data: (activities) {
                final queryLower = _query.toLowerCase();
                final hasExact = activities.any((a) => a.name.toLowerCase() == queryLower);
                return ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    if (_query.isNotEmpty && !hasExact)
                      _ResultTile(
                        name: _query, isNew: true,
                        onTap: () => setState(() => _selectedName = _query),
                      ),
                    ...activities.map((a) => _ResultTile(
                          name: a.name,
                          muscleGroup: a.muscleGroup,
                          activity: a,
                          onTap: () => setState(() {
                            _selectedName = a.name;
                            _addActivityType = a.activityType;
                            _selectedActivity = a;
                          }),
                        )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: AppColors.textSecondary))),
            ),
          ),
      ],
    );
  }

  Widget _buildAddConfig(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected exercise chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(_selectedName!, style: const TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primary))),
                // Eye icon for form preview
                if (_selectedActivity != null && _selectedActivity!.hasFormImage)
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 20, color: AppColors.primary),
                    tooltip: 'View form',
                    onPressed: () => showExerciseFormPreview(context, _selectedActivity!),
                    padding: const EdgeInsets.only(left: 4),
                    constraints: const BoxConstraints(),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                  onPressed: () => setState(() { _selectedName = null; _selectedActivity = null; }),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Text('Type:', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              _MiniToggle(selected: _addActivityType == 'reps', label: 'Reps', onTap: () => setState(() => _addActivityType = 'reps')),
              const SizedBox(width: 8),
              _MiniToggle(selected: _addActivityType == 'time', label: 'Time', onTap: () => setState(() => _addActivityType = 'time')),
            ]),
            const SizedBox(height: 20),
            _StepRow(label: 'Sets', value: _addSets, min: 1, max: 20, onChanged: (v) => setState(() => _addSets = v)),
            const SizedBox(height: 16),
            if (_addActivityType == 'reps')
              _StepRow(label: 'Reps', value: _addReps, min: 1, max: 100, onChanged: (v) => setState(() => _addReps = v))
            else
              _StepRow(label: 'Duration (sec)', value: _addDuration, min: 5, max: 3600, step: 5,
                  onChanged: (v) => setState(() => _addDuration = v),
                  suffix: '${_addDuration ~/ 60}:${(_addDuration % 60).toString().padLeft(2, '0')}'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAdding ? null : _addExercise,
                icon: _isAdding
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                    : const Icon(Icons.add_rounded),
                label: Text(_isAdding ? 'ADDING...' : 'ADD TO WORKOUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit View ──────────────────────────────────────────────────────────────
  Widget _buildEditView(BuildContext context, ScrollController scrollCtrl) {
    final ex = _editTarget!;
    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => setState(() { _view = _ManagerView.list; _editTarget = null; }),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Edit ${ex.exerciseName}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ex.completedSets > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${ex.completedSets} set${ex.completedSets > 1 ? 's' : ''} already completed and will be preserved.',
                  style: const TextStyle(fontSize: 12, color: AppColors.accent),
                )),
              ]),
            ),
          const Divider(height: 20),
          // Type toggle
          Row(children: [
            Text('Type:', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            _MiniToggle(selected: _editActivityType == 'reps', label: 'Reps', onTap: () => setState(() => _editActivityType = 'reps')),
            const SizedBox(width: 8),
            _MiniToggle(selected: _editActivityType == 'time', label: 'Time', onTap: () => setState(() => _editActivityType = 'time')),
          ]),
          const SizedBox(height: 20),
          _StepRow(
            label: 'Total Sets',
            value: _editSets,
            min: ex.completedSets > 0 ? ex.completedSets : 1,
            max: 20,
            onChanged: (v) => setState(() => _editSets = v),
          ),
          const SizedBox(height: 16),
          if (_editActivityType == 'reps')
            _StepRow(label: 'Reps per Set', value: _editReps, min: 1, max: 100, onChanged: (v) => setState(() => _editReps = v))
          else
            _StepRow(
              label: 'Duration (sec)',
              value: _editDuration,
              min: 5, max: 3600, step: 5,
              onChanged: (v) => setState(() => _editDuration = v),
              suffix: '${_editDuration ~/ 60}:${(_editDuration % 60).toString().padLeft(2, '0')}',
            ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingEdit ? null : _saveEdit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700),
              ),
              child: _isSavingEdit
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary))
                  : const Text('SAVE CHANGES'),
            ),
          ),
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

// ---------------------------------------------------------------------------
// Pulsing timer display for time-based exercises
// ---------------------------------------------------------------------------
class _PulsingTimerDisplay extends StatefulWidget {
  final String timeStr;
  final Color color;
  final bool isPulsing;
  const _PulsingTimerDisplay({required this.timeStr, required this.color, required this.isPulsing});

  @override
  State<_PulsingTimerDisplay> createState() => _PulsingTimerDisplayState();
}

class _PulsingTimerDisplayState extends State<_PulsingTimerDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_PulsingTimerDisplay old) {
    super.didUpdateWidget(old);
    if (widget.isPulsing && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isPulsing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(
        scale: widget.isPulsing ? _scale.value : 1.0,
        child: child,
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
          fontFamily: 'BarlowCondensed',
          fontSize: 72,
          fontWeight: FontWeight.w800,
          color: widget.color,
          letterSpacing: 2,
          shadows: [
            Shadow(color: widget.color.withOpacity(0.4), blurRadius: 20),
          ],
        ),
        child: Text(widget.timeStr),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time set result bottom sheet
// ---------------------------------------------------------------------------
class _TimeSetResultSheet extends StatelessWidget {
  final SetComparisonModel comparison;
  final String exerciseName;
  final int setNumber;
  final int durationSeconds;

  const _TimeSetResultSheet({
    required this.comparison,
    required this.exerciseName,
    required this.setNumber,
    required this.durationSeconds,
  });

  static String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isNewPB = comparison.isNewTopRecord;
    final beatLast = comparison.durationChange > 0 && !isNewPB;
    final declined = comparison.durationChange < 0;

    Color accentColor;
    String headline;
    String subline;
    IconData icon;

    if (isNewPB) {
      accentColor = const Color(0xFFFFD700);
      headline = '🏆 NEW PERSONAL BEST!';
      subline = 'Absolutely crushing it — ${_fmt(durationSeconds)} is your new all-time record for $exerciseName!';
      icon = Icons.emoji_events_rounded;
    } else if (beatLast) {
      accentColor = const Color(0xFFFF8C00);
      headline = '🔥 Beat Your Last Record!';
      subline = '+${comparison.durationChange}s over your previous ${_fmt(comparison.prevDurationSeconds)} — incredible work!';
      icon = Icons.trending_up_rounded;
    } else if (declined) {
      accentColor = AppColors.textSecondary;
      headline = 'Good work!';
      subline = 'Every rep counts. You\'ll crush ${_fmt(comparison.prevDurationSeconds)} next time.';
      icon = Icons.thumb_up_rounded;
    } else {
      accentColor = AppColors.accent;
      headline = 'Matched Your Record! 💪';
      subline = 'Consistent and strong — ${_fmt(durationSeconds)} just like last time!';
      icon = Icons.check_circle_rounded;
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 32, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 40),
            ),

            const SizedBox(height: 16),

            // Headline
            Text(
              headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 8),

            // Your time
            Text(
              _fmt(durationSeconds),
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
            Text(
              'SET $setNumber • $exerciseName',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, letterSpacing: 1.5),
            ),

            const SizedBox(height: 14),

            // Sub message
            Text(
              subline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),

            const SizedBox(height: 24),

            // Dismiss
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                child: const Text('KEEP GOING 💪'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ResultTile extends StatelessWidget {
  final String name;
  final String? muscleGroup;
  final bool isNew;
  final VoidCallback onTap;
  final MasterActivityModel? activity; // full model for eye preview
  const _ResultTile({required this.name, this.muscleGroup, this.isNew = false, required this.onTap, this.activity});

  @override
  Widget build(BuildContext context) {
    final hasPreview = activity != null && activity!.hasFormImage;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isNew ? AppColors.primaryMuted : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isNew ? AppColors.primary.withOpacity(0.3) : AppColors.border),
        ),
        child: Row(children: [
          Icon(isNew ? Icons.add_circle_outline_rounded : Icons.fitness_center_rounded, size: 18, color: isNew ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isNew ? 'Add "$name" as new' : name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isNew ? AppColors.primary : AppColors.textPrimary)),
            if (muscleGroup != null) Text(muscleGroup!, style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
          ])),
          if (hasPreview)
            GestureDetector(
              onTap: () => showExerciseFormPreview(context, activity!),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.remove_red_eye_rounded,
                  size: 18,
                  color: AppColors.primary.withOpacity(0.8),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const _MiniToggle({required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.textOnPrimary : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final void Function(int) onChanged;
  final String? suffix;
  const _StepRow({required this.label, required this.value, required this.min, required this.max, this.step = 1, required this.onChanged, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
      const Spacer(),
      IconButton(onPressed: value > min ? () => onChanged(value - step) : null, icon: const Icon(Icons.remove_circle_outline_rounded), color: AppColors.primary, disabledColor: AppColors.textDisabled),
      Container(width: 56, alignment: Alignment.center, child: Text(suffix ?? '$value', style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      IconButton(onPressed: value < max ? () => onChanged(value + step) : null, icon: const Icon(Icons.add_circle_outline_rounded), color: AppColors.primary, disabledColor: AppColors.textDisabled),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Muscle filter chips — horizontally scrollable pill row
// ---------------------------------------------------------------------------
class _MuscleFilterChips extends StatelessWidget {
  final String? selected;
  final List<String> muscles;
  final ValueChanged<String?> onChanged;

  const _MuscleFilterChips({
    required this.selected,
    required this.muscles,
    required this.onChanged,
  });

  String _cap(String s) => s.isEmpty
      ? s
      : s.split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(label: 'All', selected: selected == null, onTap: () => onChanged(null)),
          const SizedBox(width: 6),
          ...muscles.map(
            (m) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Chip(
                label: _cap(m),
                selected: selected == m,
                onTap: () => onChanged(selected == m ? null : m),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
