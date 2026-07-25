import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter helper service to control iOS Live Activities & Dynamic Island timer via Swift MethodChannel.
class LiveActivityService {
  LiveActivityService._();

  static const _channel = MethodChannel('com.vivian.gymtracker/live_activity');

  /// Returns null on success, or an error message string on failure.
  static Future<String?> startLiveActivity({
    required String planName,
    required String currentExercise,
    int? currentSet,
    int? totalSets,
    bool isResting = false,
    int? restEndTimeMillis,
  }) async {
    try {
      final res = await _channel.invokeMethod('startLiveActivity', {
        'planName': planName,
        'currentExercise': currentExercise,
        if (currentSet != null) 'currentSet': currentSet,
        if (totalSets != null) 'totalSets': totalSets,
        'isResting': isResting,
        if (restEndTimeMillis != null) 'restEndTimeMillis': restEndTimeMillis,
      });
      debugPrint('[LiveActivityService] startLiveActivity result: $res');
      return null;
    } on PlatformException catch (e) {
      final msg = '[LiveActivity] ${e.code}: ${e.message}';
      debugPrint(msg);
      return msg;
    } catch (e) {
      final msg = '[LiveActivity] Error: $e';
      debugPrint(msg);
      return msg;
    }
  }

  static Future<void> updateLiveActivity({
    String? currentExercise,
    int? currentSet,
    int? totalSets,
    bool? isResting,
    int? restEndTimeMillis,
  }) async {
    try {
      await _channel.invokeMethod('updateLiveActivity', {
        if (currentExercise != null) 'currentExercise': currentExercise,
        if (currentSet != null) 'currentSet': currentSet,
        if (totalSets != null) 'totalSets': totalSets,
        if (isResting != null) 'isResting': isResting,
        if (restEndTimeMillis != null) 'restEndTimeMillis': restEndTimeMillis,
      });
    } catch (e) {
      debugPrint('[LiveActivityService] updateLiveActivity failed: $e');
    }
  }

  static Future<void> stopLiveActivity() async {
    try {
      await _channel.invokeMethod('stopLiveActivity');
    } catch (e) {
      debugPrint('[LiveActivityService] stopLiveActivity failed: $e');
    }
  }
}
