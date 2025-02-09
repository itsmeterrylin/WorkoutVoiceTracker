//
//  WCSessionManager.swift
//  WorkoutVoiceTracker
//
//  Created by Terry Lin on 2/8/25.
//
import WatchConnectivity
import CoreData

class WCSessionManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WCSessionManager()
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    /// ✅ Send workout data from Watch to iPhone
    func sendWorkout(date: Date, duration: Double, source: String) {
        if WCSession.default.isReachable {
            let workoutData: [String: Any] = [
                "date": date,
                "duration": duration,
                "source": source
            ]
            WCSession.default.sendMessage(workoutData, replyHandler: nil, errorHandler: { error in
                print("❌ Failed to send workout: \(error.localizedDescription)")
            })
        } else {
            print("⚠️ WCSession is not reachable.")
        }
    }
    
    /// ✅ Listen for incoming workouts on iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let date = message["date"] as? Date,
              let duration = message["duration"] as? Double,
              let source = message["source"] as? String else {
            print("⚠️ Invalid workout data received.")
            return
        }
        
        DispatchQueue.main.async {
            self.saveWorkout(date: date, duration: duration, source: source)
        }
    }
    
    /// ✅ Save received workout to Core Data and trigger iCloud sync
    private func saveWorkout(date: Date, duration: Double, source: String) {
        let context = PersistenceController.shared.container.viewContext
        let newWorkout = Workout(context: context)
        newWorkout.id = UUID()
        newWorkout.date = date
        newWorkout.duration = duration
        newWorkout.source = source
        
        do {
            try context.save()
            print("✅ Workout received and saved from \(source)")
            
            // ✅ Trigger iCloud sync immediately
            DispatchQueue.global(qos: .background).async {
                self.forceiCloudSync()
            }
            
            // ✅ Notify iPhone UI to refresh
            NotificationCenter.default.post(name: NSNotification.Name("WorkoutReceived"), object: nil)
            
        } catch {
            print("❌ Failed to save workout: \(error.localizedDescription)")
        }
    }
    
    /// ✅ Force an immediate iCloud push
    public func forceiCloudSync() {
        let context = PersistenceController.shared.container.viewContext
        
        do {
            try context.save()  // Ensure latest changes are persisted
            print("☁️ iCloud push initiated.")
            
            // ✅ Trigger iCloud sync manually
            let container = PersistenceController.shared.container
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                print("🔄 iCloud sync manually triggered.")
            }
        } catch {
            print("❌ Error forcing iCloud sync: \(error.localizedDescription)")
        }
    }
    
    // MARK: - ✅ Required WCSessionDelegate Methods
    
    /// ✅ Required for iOS: Handle session activation
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("✅ WCSession activated successfully. State: \(state.rawValue)")
        }
    }
    
#if os(iOS)  // ✅ Only compile these methods for iOS
    /// ✅ Required for iPhone: Handle WatchOS app going inactive
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ WCSession became inactive.")
    }
    
    /// ✅ Required for iPhone: Handle WatchOS app being deactivated
    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ WCSession deactivated. Reactivating session.")
        WCSession.default.activate()
    }
#endif
}
