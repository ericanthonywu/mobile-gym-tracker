//
//  GymTrackerWidgetLiveActivity.swift
//  GymTrackerWidget
//
//  Created by Eric Anthony on 26/07/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct GymTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct GymTrackerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymTrackerWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension GymTrackerWidgetAttributes {
    fileprivate static var preview: GymTrackerWidgetAttributes {
        GymTrackerWidgetAttributes(name: "World")
    }
}

extension GymTrackerWidgetAttributes.ContentState {
    fileprivate static var smiley: GymTrackerWidgetAttributes.ContentState {
        GymTrackerWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: GymTrackerWidgetAttributes.ContentState {
         GymTrackerWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: GymTrackerWidgetAttributes.preview) {
   GymTrackerWidgetLiveActivity()
} contentStates: {
    GymTrackerWidgetAttributes.ContentState.smiley
    GymTrackerWidgetAttributes.ContentState.starEyes
}
