//
//  WorkoutVoiceTrackerApp.swift
//  WorkoutVoiceTracker
//
//  Created by Terry Lin on 2/1/25.
//

import SwiftUI

@main
struct WorkoutVoiceTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
