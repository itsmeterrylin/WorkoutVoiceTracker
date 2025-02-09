//
//  CoreDataManager.swift
//  WorkoutVoiceTracker
//
//  Created by Terry Lin on 2/5/25.
//

import CoreData
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    let persistentContainer: NSPersistentContainer

    private init() {
        persistentContainer = NSPersistentContainer(name: "WorkoutVoiceTracker") // Ensure this matches your .xcdatamodeld file name
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
    }

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Data saved successfully")
            } catch {
                print("❌ Failed to save data: \(error.localizedDescription)")
            }
        }
    }
}
