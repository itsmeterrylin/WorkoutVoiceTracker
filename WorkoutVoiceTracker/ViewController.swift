import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Call the test data function
        insertTestData()
        
        // Fetch and print workouts
        fetchWorkouts()
    }

    func fetchWorkouts() {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()

        do {
            let workouts = try context.fetch(fetchRequest)
            for workout in workouts {
                print("📅 Workout on \(workout.date ?? Date()), Duration: \(workout.duration) min")
                
                if let exercises = workout.exercises as? Set<Exercise> {
                    for exercise in exercises {
                        print("🏋️ Exercise: \(exercise.name ?? "Unknown")")
                        
                        if let sets = exercise.sets as? Set<Set> {
                            for set in sets {
                                print("🔢 Set: \(set.reps) reps, \(set.weight) \(set.unit ?? "kg")")
                            }
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch workouts: \(error.localizedDescription)")
        }
    }
}
