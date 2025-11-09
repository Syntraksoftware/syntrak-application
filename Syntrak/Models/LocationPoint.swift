import Foundation
import CoreLocation

struct LocationPoint: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let speed: Double // m/s
    let course: Double // degrees
    
    init(id: UUID = UUID(), latitude: Double, longitude: Double, altitude: Double = 0, timestamp: Date = Date(), speed: Double = 0, course: Double = 0) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.course = course
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(from location: CLLocation) {
        self.id = UUID()
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = location.timestamp
        self.speed = location.speed >= 0 ? location.speed : 0
        self.course = location.course >= 0 ? location.course : 0
    }
}

