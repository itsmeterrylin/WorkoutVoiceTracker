// WorkoutVoiceTracker > App > ContentView.swift
// For iOS
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        entity: Workout.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Workout.date, ascending: false)]
    ) private var workouts: FetchedResults<Workout>

    @State private var cloudKitListener: NSObjectProtocol?

    var body: some View {
        NavigationView {
            List {
                ForEach(workouts.sorted(by: { $0.date ?? Date() > $1.date ?? Date() })) { workout in
                    VStack(alignment: .leading) {
                        Text("\(workout.date ?? Date(), formatter: dateTimeFormatter)")
                            .font(.headline)
                        Text("Duration: \(workout.duration, specifier: "%.1f") min")
                            .font(.subheadline)
                        Text("Source: \(workout.source ?? "Unknown")") // ✅ Show source
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete(perform: deleteWorkout)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: syncWithCloud) {
                        Label("Sync", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .bottomBar) { // ✅ Add button at bottom
                    Button(action: addWorkout) {
                        Label("Add Workout", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Workouts")
            .onAppear {
                refreshData()
                startListeningForCloudKitChanges()

                // ✅ Listen for Watch-to-iPhone workout updates
                NotificationCenter.default.addObserver(forName: NSNotification.Name("WorkoutReceived"), object: nil, queue: .main) { _ in
                    print("🔄 Detected new workout from Watch, refreshing UI and pushing to iCloud.")
                    refreshData()
                    DispatchQueue.global(qos: .background).async {
                        DispatchQueue.global(qos: .background).async {
                            WCSessionManager.shared.forceiCloudSync()
                        }
                    }
                }
            
            }
            .onDisappear {
                stopListeningForCloudKitChanges()
            }
        }
    }

    /// ✅ Function to create a new workout
    private func addWorkout() {
        let newWorkout = Workout(context: viewContext)
        newWorkout.id = UUID()
        newWorkout.date = Date()
        newWorkout.duration = Double.random(in: 20...90) // Generate random duration

        #if os(iOS)
        newWorkout.source = "iPhone"
        print("📱 Workout created from iPhone")
        #elseif os(watchOS)
        newWorkout.source = "Watch"
        print("⌚ Workout created from Apple Watch")
        #else
        print("⚠️ Unknown device type")
        #endif

        do {
            try viewContext.save()
            print("✅ Workout created successfully from \(newWorkout.source!)")
        } catch {
            print("❌ Failed to create workout: \(error.localizedDescription)")
        }
    }

    private func startListeningForCloudKitChanges() {
        cloudKitListener = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 Detected iCloud sync change, refreshing data.")
            refreshData()
        }
    }

    private func stopListeningForCloudKitChanges() {
        if let observer = cloudKitListener {
            NotificationCenter.default.removeObserver(observer)
            print("❌ Stopped listening for iCloud sync changes.")
        }
    }

    private func syncWithCloud() {
        print("🔄 Manually triggering iCloud sync...")
        refreshData()
    }

    private func refreshData() {
        viewContext.refreshAllObjects()
        print("🔄 Refreshing Core Data")

        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Workout.date, ascending: false)]

        do {
            let fetchedWorkouts = try viewContext.fetch(fetchRequest)

            // ✅ Ensure sorting after fetch
            let sortedWorkouts = fetchedWorkouts.sorted { $0.date ?? Date() > $1.date ?? Date() }
            
            print("📋 Fetched \(sortedWorkouts.count) workouts from Core Data (sorted by most recent).")
        } catch {
            print("❌ Failed to fetch workouts: \(error.localizedDescription)")
        }
    }

    private func deleteWorkout(offsets: IndexSet) {
        withAnimation {
            offsets.map { workouts[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
                print("🗑️ Workout deleted successfully")
            } catch {
                print("❌ Failed to delete workout: \(error.localizedDescription)")
            }
        }
    }
}

private let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()
