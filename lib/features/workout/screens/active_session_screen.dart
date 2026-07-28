import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/features/workout/models/set_comparison_model.dart';
import 'package:gym_tracker/features/workout/models/workout_session_model.dart';
import 'package:gym_tracker/features/workout/providers/master_activity_provider.dart';
import 'package:gym_tracker/features/workout/providers/rest_timer_provider.dart';
import 'package:gym_tracker/features/workout/providers/session_provider.dart';
import 'package:gym_tracker/features/workout/screens/set_result_screen.dart';

/// Phase of the current set: actively performing the exercise, or logging results.
enum _SetPhase { executing, logging }

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
              icon: const Icon(Icons.list_rounded),
              onPressed: () => _showExerciseSidebar(context, session),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
              onPressed: () => _showAddExerciseSheet(context, session),
              tooltip: 'Add exercise',
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

              if (nextSet != null && !timer.isActive) ...[
                // Show execution view or logging view depending on phase
                if (_setPhase == _SetPhase.executing && !nextSet.isTimeBased)
                  _buildSetExecutionView(context, session, nextSet)
                else
                  _buildCurrentSetInput(context, session, nextSet),
              ] else if (timer.isActive) ...[
                // Rest timer (logging input is shown above/below)
                _buildRestTimerWithInput(context, session, timer),
              ] else ...[
                // Session complete — show summary
                _buildSessionComplete(context, session),
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
                    'SET ${nextSet.setNumber}',
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

        // ── DONE button — transitions to logging phase + starts rest timer ──
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _stopSetTimer();
              // Start rest timer immediately in background
              final ex = exercise;
              ref.read(restTimerProvider.notifier).start(
                exerciseName: nextSet.exerciseName,
                nextSetNumber: nextSet.setNumber,
                totalSets: ex.totalSets,
              );
              // Clear any old input and switch to logging phase
              _repsCtrl.clear();
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
                Text('DONE — LOG REPS'),
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

  Widget _buildCurrentSetInput(BuildContext context, WorkoutSessionModel session, SessionSetModel nextSet) {
    final exercise = session.exercises.firstWhere((e) => e.sets.contains(nextSet));

    // When the active set changes, reset and auto-start (safe post-frame, no build-phase mutation)
    if (_activeSetId != nextSet.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSetActivated(nextSet);
      });
    }

    // Pre-fill from last session's values (smart defaults)
    if (_repsCtrl.text.isEmpty && nextSet.defaultReps != null) {
      _repsCtrl.text = nextSet.defaultReps!.toString();
    }
    if (_weightCtrl.text.isEmpty && nextSet.defaultWeightKg != null) {
      _weightCtrl.text = nextSet.defaultWeightKg!.toStringAsFixed(1);
    }

    // Time-based branch
    if (nextSet.isTimeBased) {
      return _buildTimeSetInput(context, session, nextSet, exercise);
    }

    // ── Reps-based (original) ──
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
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
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

  // ── Shared exercise header card ──
  Widget _buildExerciseHeader(BuildContext context, SessionSetModel nextSet, ExerciseSessionModel exercise, String? hint) {
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
    );
  }

  // ── Time-based set input: count-up stopwatch with milestone states ──
  Widget _buildTimeSetInput(BuildContext context, WorkoutSessionModel session, SessionSetModel nextSet, ExerciseSessionModel exercise) {
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
        final nextSet = updatedSession?.nextSet;
        int? totalSets;
        if (nextSet != null && updatedSession != null) {
          final ex = updatedSession.exercises.firstWhere(
            (e) => e.exerciseName == nextSet.exerciseName,
            orElse: () => updatedSession.exercises.first,
          );
          totalSets = ex.totalSets;
        }
        ref.read(restTimerProvider.notifier).start(
          exerciseName: nextSet?.exerciseName ?? set.exerciseName,
          nextSetNumber: nextSet?.setNumber,
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

      // Show result screen if we have comparison data
      if (comparison != null && mounted) {
        await SetResultScreen.show(
          context,
          comparison: comparison,
          exerciseName: set.exerciseName,
          setNumber: set.setNumber,
          reps: reps,
          weightKg: weightKg,
        );
      }

      // Reset phase for the next set
      _activeSetId = null;
      setState(() => _setPhase = _SetPhase.executing);

      // Start rest timer (already started in execution phase for reps, but refresh with new set info)
      final updatedSession = ref.read(activeSessionNotifierProvider).value;
      final nextSet = updatedSession?.nextSet;
      int? totalSets;
      if (nextSet != null && updatedSession != null) {
        final ex = updatedSession.exercises.firstWhere(
          (e) => e.exerciseName == nextSet.exerciseName,
          orElse: () => updatedSession.exercises.first,
        );
        totalSets = ex.totalSets;
      }
      // If rest timer is already running (started from execution phase DONE tap), update it
      // If not running (user skipped execution phase), start it now
      if (!ref.read(restTimerProvider).isActive) {
        ref.read(restTimerProvider.notifier).start(
          exerciseName: nextSet?.exerciseName ?? set.exerciseName,
          nextSetNumber: nextSet?.setNumber,
          totalSets: totalSets,
        );
      }
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

  void _showExerciseSidebar(BuildContext context, WorkoutSessionModel session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExerciseSidebar(session: session),
    );
  }

  /// Mid-session: add a new exercise to the ongoing session.
  void _showAddExerciseSheet(BuildContext context, WorkoutSessionModel session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MidSessionAddExerciseSheet(
        sessionId: session.id,
        onAdded: () {
          // Refresh session state after adding
          ref.read(activeSessionNotifierProvider.notifier).load();
        },
      ),
    );
  }

  /// Rest timer shown while user is logging reps/weight (rest runs in background).
  /// Combines the circular rest countdown at the top with the log input below.
  Widget _buildRestTimerWithInput(BuildContext context, WorkoutSessionModel session, RestTimerState timer) {
    // If phase is 'logging', show the logging form with rest timer mini-indicator at top
    // If rest is over, go back to execution view
    if (timer.isRestOver) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alarm_on_rounded, color: AppColors.accent, size: 56),
          ),
          const SizedBox(height: 16),
          Text(
            'REST TIME OVER!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            timer.exerciseName != null
                ? 'Ready for ${timer.exerciseName}?'
                : 'Ready for your next set?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(restTimerProvider.notifier).stop();
                setState(() => _setPhase = _SetPhase.executing);
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('START NEXT SET'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'NEED MORE REST?',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () { HapticFeedback.lightImpact(); ref.read(restTimerProvider.notifier).extendRest(15); },
                  child: const Text('+15s'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () { HapticFeedback.lightImpact(); ref.read(restTimerProvider.notifier).extendRest(30); },
                  child: const Text('+30s'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () { HapticFeedback.lightImpact(); ref.read(restTimerProvider.notifier).extendRest(60); },
                  child: const Text('+60s'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Rest is still counting — show mini rest indicator + logging form
    final mins = timer.remainingSeconds ~/ 60;
    final secs = timer.remainingSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final nextSetSession = session;
    final nextSet = nextSetSession.nextSet;

    return Column(
      children: [
        // Mini rest countdown banner at top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.1),
                AppColors.surfaceVariant.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(36, 36),
                      painter: _TimerPainter(progress: timer.progress),
                    ),
                    Text(
                      '$secs',
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REST  •  $timeStr remaining',
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Log your reps while you rest',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              // Adjust rest
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TimerAdjustButton(label: '-15s', onTap: () => ref.read(restTimerProvider.notifier).adjustDuration(-15)),
                  const SizedBox(width: 4),
                  _TimerAdjustButton(label: '+15s', onTap: () => ref.read(restTimerProvider.notifier).adjustDuration(15)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Skip rest button (small)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(restTimerProvider.notifier).stop();
              setState(() => _setPhase = _SetPhase.executing);
            },
            child: const Text('Skip Rest →', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
        ),

        const SizedBox(height: 8),

        // Logging form (reps/weight input)
        if (nextSet != null) ...[
          _buildCurrentSetInput(context, session, nextSet),
        ],
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

// ---------------------------------------------------------------------------
// Mid-session: Add exercise sheet
// ---------------------------------------------------------------------------
class _MidSessionAddExerciseSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final VoidCallback onAdded;

  const _MidSessionAddExerciseSheet({required this.sessionId, required this.onAdded});

  @override
  ConsumerState<_MidSessionAddExerciseSheet> createState() => _MidSessionAddExerciseSheetState();
}

class _MidSessionAddExerciseSheetState extends ConsumerState<_MidSessionAddExerciseSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedName;
  String _activityType = 'reps';
  int _sets = 3;
  int _reps = 12;
  int _durationSeconds = 60;
  bool _isAdding = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(activitySearchProvider(_query));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Column(
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
                Text('Add Exercise to Session',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  autofocus: true,
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
              ],
            ),
          ),
          if (_selectedName != null)
            _buildConfig(context)
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
                        _ResultTile(name: _query, isNew: true, onTap: () => setState(() => _selectedName = _query)),
                      ...activities.map((a) => _ResultTile(
                            name: a.name,
                            muscleGroup: a.muscleGroup,
                            onTap: () => setState(() {
                              _selectedName = a.name;
                              _activityType = a.activityType;
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
      ),
    );
  }

  Widget _buildConfig(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary), onPressed: () => setState(() => _selectedName = null), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Text('Type:', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              _MiniToggle(selected: _activityType == 'reps', label: 'Reps', onTap: () => setState(() => _activityType = 'reps')),
              const SizedBox(width: 8),
              _MiniToggle(selected: _activityType == 'time', label: 'Time', onTap: () => setState(() => _activityType = 'time')),
            ]),
            const SizedBox(height: 20),
            _StepRow(label: 'Sets', value: _sets, min: 1, max: 20, onChanged: (v) => setState(() => _sets = v)),
            const SizedBox(height: 16),
            if (_activityType == 'reps')
              _StepRow(label: 'Reps', value: _reps, min: 1, max: 100, onChanged: (v) => setState(() => _reps = v))
            else
              _StepRow(label: 'Duration (sec)', value: _durationSeconds, min: 5, max: 3600, step: 5, onChanged: (v) => setState(() => _durationSeconds = v), suffix: '${_durationSeconds ~/ 60}:${(_durationSeconds % 60).toString().padLeft(2, '0')}'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAdding ? null : () async {
                  setState(() => _isAdding = true);
                  try {
                    await ref.read(activeSessionNotifierProvider.notifier).addExercise(
                      widget.sessionId,
                      name: _selectedName!,
                      targetSets: _sets,
                      targetReps: _activityType == 'reps' ? _reps : 0,
                      activityType: _activityType,
                      targetDurationSeconds: _activityType == 'time' ? _durationSeconds : null,
                    );
                    widget.onAdded();
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
                      setState(() => _isAdding = false);
                    }
                  }
                },
                icon: _isAdding ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary)) : const Icon(Icons.add_rounded),
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
}

class _ResultTile extends StatelessWidget {
  final String name;
  final String? muscleGroup;
  final bool isNew;
  final VoidCallback onTap;
  const _ResultTile({required this.name, this.muscleGroup, this.isNew = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
