import Flutter
import UIKit
import ActivityKit

struct GymTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var planName: String
        var startDate: Date
        var currentExercise: String
        var isResting: Bool
        var restEndDate: Date?
    }

    var title: String
}

class SceneDelegate: FlutterSceneDelegate {
  private var liveActivity: Any? = nil

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let windowScene = scene as? UIWindowScene,
          let controller = windowScene.windows.first?.rootViewController as? FlutterViewController else {
      return
    }

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
        self?.startLiveActivity(planName: planName, currentExercise: currentExercise, args: args, result: result)
      } else if call.method == "updateLiveActivity" {
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        self?.updateLiveActivity(args: args, result: result)
      } else if call.method == "stopLiveActivity" {
        self?.stopLiveActivity(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }

  private func startLiveActivity(planName: String, currentExercise: String, args: [String: Any], result: @escaping FlutterResult) {
    if #available(iOS 16.2, *) {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        print("[LiveActivity] Activities disabled on device.")
        result(FlutterError(code: "DISABLED", message: "Live Activities disabled on device.", details: nil))
        return
      }

      let isResting = args["isResting"] as? Bool ?? false
      let restEndDate: Date?
      if let restEndTimeMillis = args["restEndTimeMillis"] as? Double {
        restEndDate = Date(timeIntervalSince1970: restEndTimeMillis / 1000.0)
      } else if let restEndTimeMillisInt = args["restEndTimeMillis"] as? Int64 {
        restEndDate = Date(timeIntervalSince1970: Double(restEndTimeMillisInt) / 1000.0)
      } else {
        restEndDate = nil
      }

      let attributes = GymTrackerWidgetAttributes(title: "Gym Tracker")
      let initialState = GymTrackerWidgetAttributes.ContentState(
        planName: planName,
        startDate: Date(),
        currentExercise: currentExercise,
        isResting: isResting,
        restEndDate: restEndDate
      )

      do {
        let content = ActivityContent(state: initialState, staleDate: nil)
        let activity = try Activity<GymTrackerWidgetAttributes>.request(
          attributes: attributes,
          content: content,
          pushType: nil
        )
        self.liveActivity = activity
        print("[LiveActivity] Started Activity ID: \(activity.id)")
        result(true)
      } catch {
        print("[LiveActivity] Request error: \(error)")
        result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
      }
    } else {
      result(FlutterError(code: "UNSUPPORTED", message: "iOS 16.2+ required for Live Activities", details: nil))
    }
  }

  private func updateLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
    if #available(iOS 16.2, *) {
      Task {
        for activity in Activity<GymTrackerWidgetAttributes>.activities {
          let currentState = activity.content.state
          let exercise = (args["currentExercise"] as? String) ?? currentState.currentExercise
          let isResting = (args["isResting"] as? Bool) ?? currentState.isResting

          let restEndDate: Date?
          if let restEndTimeMillis = args["restEndTimeMillis"] as? Double {
            restEndDate = Date(timeIntervalSince1970: restEndTimeMillis / 1000.0)
          } else if let restEndTimeMillisInt = args["restEndTimeMillis"] as? Int64 {
            restEndDate = Date(timeIntervalSince1970: Double(restEndTimeMillisInt) / 1000.0)
          } else if args.keys.contains("isResting") && !(args["isResting"] as? Bool ?? false) {
            restEndDate = nil
          } else {
            restEndDate = currentState.restEndDate
          }

          let updatedState = GymTrackerWidgetAttributes.ContentState(
            planName: currentState.planName,
            startDate: currentState.startDate,
            currentExercise: exercise,
            isResting: isResting,
            restEndDate: restEndDate
          )
          await activity.update(ActivityContent(state: updatedState, staleDate: nil))
        }
        result(true)
      }
    } else {
      result(true)
    }
  }

  private func stopLiveActivity(result: @escaping FlutterResult) {
    if #available(iOS 16.2, *) {
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
