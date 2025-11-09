import SwiftUI
import MapKit

struct ActivityDetailView: View {
    let activity: Activity
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Map
                if !activity.locations.isEmpty {
                    RouteMapView(locations: activity.locations)
                        .frame(height: 300)
                        .cornerRadius(12)
                }
                
                // Stats
                VStack(spacing: 16) {
                    StatRow(title: "Distance", value: activity.formattedDistance, icon: "ruler")
                    StatRow(title: "Duration", value: activity.formattedDuration, icon: "clock")
                    StatRow(title: "Pace", value: "\(activity.averagePace)/km", icon: "speedometer")
                    StatRow(title: "Type", value: activity.type.rawValue, icon: activity.type.icon)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Date info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Details")
                        .font(.headline)
                    Text("Started: \(activity.startTime, style: .date) at \(activity.startTime, style: .time)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let endTime = activity.endTime {
                        Text("Ended: \(endTime, style: .date) at \(endTime, style: .time)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle(activity.type.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RouteMapView: UIViewRepresentable {
    let locations: [LocationPoint]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        guard !locations.isEmpty else { return }
        
        // Create polyline from locations
        let coordinates = locations.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        // Add start and end markers
        if let start = locations.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = start.coordinate
            startAnnotation.title = "Start"
            mapView.addAnnotation(startAnnotation)
        }
        
        if let end = locations.last, locations.count > 1 {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = end.coordinate
            endAnnotation.title = "End"
            mapView.addAnnotation(endAnnotation)
        }
        
        // Set region to fit the route
        let minLat = coordinates.map { $0.latitude }.min() ?? coordinates[0].latitude
        let maxLat = coordinates.map { $0.latitude }.max() ?? coordinates[0].latitude
        let minLon = coordinates.map { $0.longitude }.min() ?? coordinates[0].longitude
        let maxLon = coordinates.map { $0.longitude }.max() ?? coordinates[0].longitude
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.5,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.5
        )
        
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

