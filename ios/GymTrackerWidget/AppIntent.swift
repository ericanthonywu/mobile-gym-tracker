//
//  AppIntent.swift
//  GymTrackerWidget
//
//  Created by Eric Anthony on 26/07/26.
//

import WidgetKit
import AppIntents

@available(iOSApplicationExtension 26.2, *)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
