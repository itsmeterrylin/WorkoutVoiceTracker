//
//  ContentView.swift
//  WorkoutVoiceTrackerWatchOS Watch App
//


import SwiftUI
import CoreData

struct ContentView: View {
    let viewContext: NSManagedObjectContext  // ✅ Injected manually

    var body: some View {
        VStack {
            Text("Workout Logger")
                .font(.title2)

            Button("Log Workout") {
                addWorkout()
            }
        }
        .onAppear {
            refreshData()
        }
    }

    /// ✅ Add workout function
    private func addWorkout() {
        let newWorkout = Workout(context: viewContext)  // ✅ Fix: Use injected viewContext
        newWorkout.id = UUID()
        newWorkout.date = Date()
        newWorkout.duration = Double.random(in: 20...90)
        newWorkout.source = "Watch"

        print("⌚ Workout created on Apple Watch")

        do {
            try viewContext.save()
            print("✅ Workout saved successfully from \(newWorkout.source!)")
        } catch {
            print("❌ Failed to save workout: \(error.localizedDescription)")
        }
    }

    /// ✅ Refresh data function
    private func refreshData() {
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()

        do {
            let workouts = try viewContext.fetch(request)
            print("🔄 Fetched \(workouts.count) workouts.")
        } catch {
            print("❌ Error fetching workouts: \(error.localizedDescription)")
        }
    }
}
