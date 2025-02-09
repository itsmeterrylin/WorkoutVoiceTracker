//
//  WorkoutModelWatchOS.swift
//  WorkoutVoiceTracker
//
//  Created by Terry Lin on 2/8/25.
//

import Foundation

struct WorkoutModel: Codable {
    let date: Date
    let exercise: String
    let reps: Int
    let weight: Double
}
