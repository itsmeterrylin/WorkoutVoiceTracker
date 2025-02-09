//
//  WorkoutVoiceTrackerWatchOSApp.swift
//  WorkoutVoiceTrackerWatchOS Watch App
//
//  Created by Terry Lin on 2/6/25.
//

import SwiftUI

@main
struct WorkoutVoiceTrackerWatchOSApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView(viewContext: persistenceController.container.viewContext)  // ✅ Pass viewContext manually
        }
    }
}
