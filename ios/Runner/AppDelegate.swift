import Flutter
import UIKit
import ActivityKit

struct GymTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var planName: String
        var startDate: Date
        var currentExercise: String
    }

    var title: String
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var liveActivity: Any? = nil

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.vivian.gymtracker/live_activity",
                                         binaryMessenger: controller.binaryMessenger)
      
      channel.setMethodCallHandler({
        [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        print("[LiveActivity] MethodChannel call: \(call.method)")
        if call.method == "startLiveActivity" {
          guard let args = call.arguments as? [String: Any],
                let planName = args["planName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
          }
          let currentExercise = args["currentExercise"] as? String ?? ""
          self?.startLiveActivity(planName: planName, currentExercise: currentExercise, result: result)
        } else if call.method == "updateLiveActivity" {
          guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
          }
          let currentExercise = args["currentExercise"] as? String ?? ""
          self?.updateLiveActivity(currentExercise: currentExercise, result: result)
        } else if call.method == "stopLiveActivity" {
          self?.stopLiveActivity(result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }

    return result
  }

  private func startLiveActivity(planName: String, currentExercise: String, result: @escaping FlutterResult) {
    if #available(iOS 16.1, *) {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        print("[LiveActivity] Activities disabled on device.")
        result(FlutterError(code: "DISABLED", message: "Live Activities disabled on device.", details: nil))
        return
      }

      let attributes = GymTrackerWidgetAttributes(title: "Gym Tracker")
      let initialState = GymTrackerWidgetAttributes.ContentState(
        planName: planName,
        startDate: Date(),
        currentExercise: currentExercise
      )

      do {
        if #available(iOS 16.2, *) {
          let content = ActivityContent(state: initialState, staleDate: nil)
          let activity = try Activity<GymTrackerWidgetAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
          )
          self.liveActivity = activity
          print("[LiveActivity] Started Activity ID: \(activity.id)")
          result(true)
        } else {
          let activity = try Activity<GymTrackerWidgetAttributes>.request(
            attributes: attributes,
            contentState: initialState,
            pushType: nil
          )
          self.liveActivity = activity
          print("[LiveActivity] Started Activity ID: \(activity.id)")
          result(true)
        }
      } catch {
        print("[LiveActivity] Request error: \(error)")
        result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
      }
    } else {
      result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.1+ required", details: nil))
    }
  }

  private func updateLiveActivity(currentExercise: String, result: @escaping FlutterResult) {
    if #available(iOS 16.1, *) {
      Task {
        for activity in Activity<GymTrackerWidgetAttributes>.activities {
          let updatedState = GymTrackerWidgetAttributes.ContentState(
            planName: activity.contentState.planName,
            startDate: activity.contentState.startDate,
            currentExercise: currentExercise
          )
          if #available(iOS 16.2, *) {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
          } else {
            await activity.update(using: updatedState)
          }
        }
        result(true)
      }
    } else {
      result(true)
    }
  }

  private func stopLiveActivity(result: @escaping FlutterResult) {
    if #available(iOS 16.1, *) {
      Task {
        for activity in Activity<GymTrackerWidgetAttributes>.activities {
          await activity.end(dismissalPolicy: .immediate)
        }
        result(true)
      }
    } else {
      result(true)
    }
  }
}
