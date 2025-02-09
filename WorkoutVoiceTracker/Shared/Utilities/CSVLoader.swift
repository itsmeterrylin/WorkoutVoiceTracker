//
//  CSVLoader.swift
//  WorkoutVoiceTracker
//
//  Created by Terry Lin on 2/4/25.
//

import Foundation

// Reads a CSV file from the app bundle and returns an array of rows (each row is an array of strings)
func loadCSV(filename: String) -> [[String]] {
    guard let path = Bundle.main.path(forResource: filename, ofType: "csv") else {
        print("❌ CSV file not found: \(filename).csv")
        return []
    }
    
    do {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return content.components(separatedBy: "\n").map { $0.components(separatedBy: ",") }
    } catch {
        print("❌ Error reading CSV file: \(error)")
        return []
    }
}

// Loads workout types from CSV into Swift models
func loadWorkoutTypes() -> [WorkoutType] {
    let csvData = loadCSV(filename: "workout_types")
    var workoutTypes: [WorkoutType] = []

    for row in csvData.dropFirst() { // Skip headers
        if row.count >= 3 {
            let type = WorkoutType(
                id: Int(row[0]) ?? 0,
                name: row[1],
                description: row[2]
            )
            workoutTypes.append(type)
        }
    }
    return workoutTypes
}

func testWorkoutTypesCSV() {
    let workoutTypes = loadWorkoutTypes()
    print("✅ Successfully Loaded Workout Types:\n", workoutTypes)
}

// Call this function to check if CSV loading works
testWorkoutTypesCSV()
