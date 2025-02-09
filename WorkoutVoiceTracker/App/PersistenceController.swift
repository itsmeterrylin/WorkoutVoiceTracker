//
// PersistenceController.swift
// WorkoutVoiceTracker
// WorkoutVoiceTracker > App > PersistenceController.swift
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    private init(inMemory: Bool = false) { // ✅ Make init private to enforce singleton
        container = NSPersistentCloudKitContainer(name: "WorkoutVoiceTracker") // ✅ First, initialize Core Data container

        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        storeDescription?.shouldMigrateStoreAutomatically = true  // ✅ Enables automatic migration
        storeDescription?.shouldInferMappingModelAutomatically = true  // ✅ Ensures smooth schema updates
        storeDescription?.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.Copper.WorkoutVoiceTracker")

        if inMemory {
            storeDescription?.url = URL(fileURLWithPath: "/dev/null") // ✅ Use in-memory store for testing
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("❌ Unresolved error \(error), \(error.userInfo)")
            } else {
                print("✅ Core Data Store Loaded Successfully: \(storeDescription.url?.absoluteString ?? "No URL")")
            }
        }

        // ✅ Enable auto-sync with iCloud
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // ✅ Listen for iCloud updates
        NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { [weak self] _ in
            print("🔄 iCloud Sync Triggered")
            self?.forceiCloudSync()  // ✅ Now works correctly with weak self
        }
    }

    /// ✅ Function to trigger a manual iCloud sync
    func forceiCloudSync() {
        Task {
            do {
                try await container.viewContext.perform {
                    try self.container.viewContext.save()
                    print("✅ Manual iCloud Sync Completed")
                }
            } catch {
                print("❌ Error during iCloud Sync: \(error.localizedDescription)")
            }
        }
    }

    /// ✅ Function to delete the local Core Data store (Fixes CloudKit sync issues)
    func deleteLocalStore() {
        guard let storeDescription = container.persistentStoreDescriptions.first,
              let storeURL = storeDescription.url else {
            print("⚠️ No Core Data store URL found, skipping deletion.")
            return
        }

        let coordinator = container.persistentStoreCoordinator

        do {
            if let store = coordinator.persistentStores.first {
                try coordinator.remove(store)
                try FileManager.default.removeItem(at: storeURL)
                print("🗑️ Deleted Core Data store at \(storeURL)")
            }
        } catch {
            print("❌ Failed to delete Core Data store: \(error.localizedDescription)")
        }
    }
}
