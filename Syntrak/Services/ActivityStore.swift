import Foundation
import Combine

class ActivityStore: ObservableObject {
    @Published var activities: [Activity] = []
    
    private let saveKey = "SavedActivities"
    
    init() {
        loadActivities()
    }
    
    func addActivity(_ activity: Activity) {
        activities.insert(activity, at: 0)
        saveActivities()
    }
    
    func deleteActivity(_ activity: Activity) {
        activities.removeAll { $0.id == activity.id }
        saveActivities()
    }
    
    private func saveActivities() {
        if let encoded = try? JSONEncoder().encode(activities) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadActivities() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Activity].self, from: data) {
            activities = decoded
        }
    }
    
    var totalDistance: Double {
        activities.reduce(0) { $0 + $1.distance }
    }
    
    var totalDuration: TimeInterval {
        activities.reduce(0) { $0 + $1.duration }
    }
}

