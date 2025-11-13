import SwiftUI
import MapKit
import CoreLocation

struct RecordActivityView: View {
    @ObservedObject var activityStore: ActivityStore
    @StateObject private var locationTracker = LocationTracker()
    @State private var selectedActivityType: ActivityType = .run
    @State private var timer: Timer?
    @State private var elapsedTime: TimeInterval = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map background
                if let location = locationTracker.currentLocation {
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                    }
                    .onAppear {
                        cameraPosition = .camera(MapCamera(
                            centerCoordinate: location.coordinate,
                            distance: 1000
                        ))
                    }
                    .onChange(of: locationTracker.currentLocation) { oldValue, newValue in
                        if let newLocation = newValue, locationTracker.isTracking {
                            cameraPosition = .camera(MapCamera(
                                centerCoordinate: newLocation.coordinate,
                                distance: 1000
                            ))
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    Color(.systemGray6)
                        .ignoresSafeArea()
                }
                
                VStack {
                    Spacer()
                    
                    // Control Panel
                    VStack(spacing: 20) {
                        // Activity Type Selector
                        if !locationTracker.isTracking {
                            Picker("Activity Type", selection: $selectedActivityType) {
                                ForEach(ActivityType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }
                        
                        // Stats Display
                        if locationTracker.isTracking {
                            VStack(spacing: 12) {
                                Text(formatTime(elapsedTime))
                                    .font(.system(size: 48, weight: .bold))
                                
                                HStack(spacing: 30) {
                                    VStack {
                                        Text(formatDistance(locationTracker.calculateDistance()))
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                        Text("Distance")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack {
                                        Text(formatPace(locationTracker.calculateDistance(), elapsedTime))
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                        Text("Pace")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(radius: 10)
                            .padding(.horizontal)
                        }
                        
                        // Start/Stop Button
                        Button(action: {
                            if locationTracker.isTracking {
                                stopActivity()
                            } else {
                                startActivity()
                            }
                        }) {
                            HStack {
                                Image(systemName: locationTracker.isTracking ? "stop.fill" : "play.fill")
                                Text(locationTracker.isTracking ? "Stop" : "Start")
                            }
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(locationTracker.isTracking ? Color.red : Color.green)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        .disabled(locationTracker.authorizationStatus == .denied || locationTracker.authorizationStatus == .restricted)
                    }
                    .padding(.bottom, 40)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color(.systemBackground).opacity(0.95)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .navigationTitle("Record Activity")
            .onAppear {
                if locationTracker.authorizationStatus == .notDetermined {
                    locationTracker.requestAuthorization()
                }
            }
        }
    }
    
    private func startActivity() {
        locationTracker.startTracking()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime = locationTracker.getDuration()
        }
    }
    
    private func stopActivity() {
        locationTracker.stopTracking()
        timer?.invalidate()
        timer = nil
        
        // Create and save activity
        let locationPoints = locationTracker.locations.map { LocationPoint(from: $0) }
        let distance = locationTracker.calculateDistance()
        let duration = elapsedTime
        
        let activity = Activity(
            type: selectedActivityType,
            startTime: Date().addingTimeInterval(-duration),
            endTime: Date(),
            locations: locationPoints,
            distance: distance,
            duration: duration
        )
        
        activityStore.addActivity(activity)
        
        // Reset
        elapsedTime = 0
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let km = distance / 1000.0
        if km >= 1.0 {
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    private func formatPace(_ distance: Double, _ time: TimeInterval) -> String {
        guard time > 0 && distance > 0 else { return "--:--" }
        let pacePerKm = time / (distance / 1000.0)
        let minutes = Int(pacePerKm) / 60
        let seconds = Int(pacePerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

