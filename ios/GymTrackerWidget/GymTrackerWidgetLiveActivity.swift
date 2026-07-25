import ActivityKit
import WidgetKit
import SwiftUI

struct GymTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var planName: String
        var startDate: Date
        var currentExercise: String
    }

    var title: String
}

struct GymTrackerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymTrackerWidgetAttributes.self) { context in
            // Lock screen / Live Notification Banner
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.planName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(context.state.currentExercise)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.08, green: 0.08, blue: 0.12))
            .activitySystemActionForegroundColor(Color.orange)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "dumbbell.fill")
                            .foregroundColor(.orange)
                        Text(context.state.planName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Current: \(context.state.currentExercise)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(.orange)
            }
            .keylineTint(Color.orange)
        }
    }
}
