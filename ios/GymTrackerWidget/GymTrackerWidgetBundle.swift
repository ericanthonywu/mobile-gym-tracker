//
//  GymTrackerWidgetBundle.swift
//  GymTrackerWidget
//
//  Created by Eric Anthony on 26/07/26.
//

import WidgetKit
import SwiftUI

@main
struct GymTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        GymTrackerWidget()
        GymTrackerWidgetControl()
        GymTrackerWidgetLiveActivity()
    }
}
