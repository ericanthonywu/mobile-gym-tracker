import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/utils/live_activity_service.dart';
import 'package:gym_tracker/core/utils/notification_service.dart';

/// Rest timer state
class RestTimerState {
  final bool isRunning;
  final int totalSeconds;
  final int remainingSeconds;
  final String? exerciseName;
  final int? nextSetNumber;

  const RestTimerState({
    required this.isRunning,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.exerciseName,
    this.nextSetNumber,
  });

  double get progress => totalSeconds > 0 ? remainingSeconds / totalSeconds : 0;
  bool get isFinished => remainingSeconds <= 0;

  static const RestTimerState idle = RestTimerState(isRunning: false, totalSeconds: 120, remainingSeconds: 120);
}

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  RestTimerNotifier() : super(RestTimerState.idle);

  Timer? _timer;
  DateTime? _targetTime;

  void start({
    int durationSeconds = 120,
    String? exerciseName,
    int? nextSetNumber,
  }) {
    _timer?.cancel();
    _targetTime = DateTime.now().add(Duration(seconds: durationSeconds));

    state = RestTimerState(
      isRunning: true,
      totalSeconds: durationSeconds,
      remainingSeconds: durationSeconds,
      exerciseName: exerciseName,
      nextSetNumber: nextSetNumber,
    );

    // Schedule OS notification as backup for background
    if (exerciseName != null) {
      NotificationService.scheduleRestTimer(
        durationSeconds: durationSeconds,
        exerciseName: exerciseName,
        nextSetNumber: nextSetNumber,
      );
    }

    // Update iOS Live Activity with Rest Countdown
    LiveActivityService.updateLiveActivity(
      currentExercise: exerciseName,
      isResting: true,
      restEndTimeMillis: _targetTime?.millisecondsSinceEpoch,
    );

    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    if (_targetTime == null || !state.isRunning) return;

    final diff = _targetTime!.difference(DateTime.now()).inSeconds;
    if (diff <= 0) {
      _timer?.cancel();
      _targetTime = null;
      state = RestTimerState(
        isRunning: false,
        totalSeconds: state.totalSeconds,
        remainingSeconds: 0,
        exerciseName: state.exerciseName,
        nextSetNumber: state.nextSetNumber,
      );

      // Revert Live Activity back to standard workout mode
      LiveActivityService.updateLiveActivity(
        isResting: false,
      );
    } else {
      state = RestTimerState(
        isRunning: true,
        totalSeconds: state.totalSeconds,
        remainingSeconds: diff,
        exerciseName: state.exerciseName,
        nextSetNumber: state.nextSetNumber,
      );
    }
  }

  /// Force immediate tick evaluation (e.g. when app resumes from background)
  void checkBackgroundReturn() {
    _updateRemaining();
  }

  void stop() {
    _timer?.cancel();
    _targetTime = null;
    NotificationService.cancelRestTimer();
    state = RestTimerState.idle;

    // Revert Live Activity back to standard workout mode
    LiveActivityService.updateLiveActivity(
      isResting: false,
    );
  }

  void adjustDuration(int seconds) {
    if (!state.isRunning || _targetTime == null) return;
    _targetTime = _targetTime!.add(Duration(seconds: seconds));

    final newRemaining = _targetTime!.difference(DateTime.now()).inSeconds.clamp(0, 600);
    final newTotal = (state.totalSeconds + seconds).clamp(1, 600);

    if (state.exerciseName != null && newRemaining > 0) {
      NotificationService.scheduleRestTimer(
        durationSeconds: newRemaining,
        exerciseName: state.exerciseName!,
        nextSetNumber: state.nextSetNumber,
      );
    }

    if (newRemaining <= 0) {
      stop();
    } else {
      state = RestTimerState(
        isRunning: true,
        totalSeconds: newTotal,
        remainingSeconds: newRemaining,
        exerciseName: state.exerciseName,
        nextSetNumber: state.nextSetNumber,
      );

      LiveActivityService.updateLiveActivity(
        isResting: true,
        restEndTimeMillis: _targetTime?.millisecondsSinceEpoch,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final restTimerProvider = StateNotifierProvider<RestTimerNotifier, RestTimerState>(
  (_) => RestTimerNotifier(),
);
