import 'package:flutter/services.dart';

/// Flutter helper service to control iOS Live Activities & Dynamic Island timer via Swift MethodChannel.
class LiveActivityService {
  LiveActivityService._();

  static const _channel = MethodChannel('com.vivian.gymtracker/live_activity');

  static Future<void> startLiveActivity({required String planName, required String currentExercise}) async {
    try {
      await _channel.invokeMethod('startLiveActivity', {
        'planName': planName,
        'currentExercise': currentExercise,
      });
    } catch (_) {}
  }

  static Future<void> updateLiveActivity({required String currentExercise}) async {
    try {
      await _channel.invokeMethod('updateLiveActivity', {
        'currentExercise': currentExercise,
      });
    } catch (_) {}
  }

  static Future<void> stopLiveActivity() async {
    try {
      await _channel.invokeMethod('stopLiveActivity');
    } catch (_) {}
  }
}
