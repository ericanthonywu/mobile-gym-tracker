import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Service for updating iOS Home Screen & Lock Screen widgets via HomeWidget.
class WidgetDataService {
  WidgetDataService._();

  static const String appGroupId = 'group.com.vivian.gymtracker';
  static const String iOSWidgetName = 'GymTrackerWidget';

  /// Save today's plan and update home screen widget.
  static Future<void> updateTodayPlan(String planName, {bool isRestDay = false}) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<String>('today_plan', isRestDay ? 'Rest Day 😴' : planName);
      await HomeWidget.updateWidget(name: iOSWidgetName);
    } catch (e) {
      debugPrint('Could not update HomeWidget today_plan: $e');
    }
  }

  /// Save last logged weight and update home screen widget.
  static Future<void> updateLastWeight(double weightKg, String dateStr) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.saveWidgetData<String>('last_weight', '${weightKg.toStringAsFixed(1)} kg');
      await HomeWidget.saveWidgetData<String>('last_weight_date', dateStr);
      await HomeWidget.updateWidget(name: iOSWidgetName);
    } catch (e) {
      debugPrint('Could not update HomeWidget last_weight: $e');
    }
  }
}
