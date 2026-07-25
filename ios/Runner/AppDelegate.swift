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
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var liveActivity: Any? = nil

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupMethodChannel(messenger: controller.binaryMessenger)
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityPlugin") {
      setupMethodChannel(messenger: registrar.messenger())
    }
  }

  private func setupMethodChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.vivian.gymtracker/live_activity",
                                       binaryMessenger: messenger)
    channel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "startLiveActivity" {
        guard let args = call.arguments as? [String: Any],
              let planName = args["planName"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        self?.startLiveActivity(planName: planName, currentExercise: args["currentExercise"] as? String ?? "")
        result(true)
      } else if call.method == "updateLiveActivity" {
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        self?.updateLiveActivity(currentExercise: args["currentExercise"] as? String ?? "")
        result(true)
      } else if call.method == "stopLiveActivity" {
        self?.stopLiveActivity()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }

  private func startLiveActivity(planName: String, currentExercise: String) {
    if #available(iOS 16.1, *) {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        print("Live Activities are disabled on this device.")
        return
      }
      stopLiveActivity()
      
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
        } else {
          let activity = try Activity<GymTrackerWidgetAttributes>.request(
            attributes: attributes,
            contentState: initialState,
            pushType: nil
          )
          self.liveActivity = activity
        }
      } catch {
        print("Failed to start Live Activity: \(error)")
      }
    }
  }

  private func updateLiveActivity(currentExercise: String) {
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
      }
    }
  }

  private func stopLiveActivity() {
    if #available(iOS 16.1, *) {
      Task {
        for activity in Activity<GymTrackerWidgetAttributes>.activities {
          await activity.end(dismissalPolicy: .immediate)
        }
      }
    }
  }
}
