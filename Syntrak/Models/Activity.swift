import Foundation
import CoreLocation

struct Activity: Identifiable, Codable {
    let id: UUID
    let type: ActivityType
    let startTime: Date
    let endTime: Date?
    let locations: [LocationPoint]
    let distance: Double // in meters
    let duration: TimeInterval // in seconds
    
    var formattedDistance: String {
        let km = distance / 1000.0
        if km >= 1.0 {
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var averagePace: String {
        guard duration > 0 && distance > 0 else { return "--:--" }
        let pacePerKm = duration / (distance / 1000.0) // seconds per km
        let minutes = Int(pacePerKm) / 60
        let seconds = Int(pacePerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init(id: UUID = UUID(), type: ActivityType, startTime: Date, endTime: Date? = nil, locations: [LocationPoint] = [], distance: Double = 0, duration: TimeInterval = 0) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.locations = locations
        self.distance = distance
        self.duration = duration
    }
}

enum ActivityType: String, Codable, CaseIterable {
    case run = "Run"
    case ride = "Ride"
    case walk = "Walk"
    case hike = "Hike"
    
    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .ride: return "bicycle"
        case .walk: return "figure.walk"
        case .hike: return "figure.hiking"
        }
    }
}

