import SwiftUI

struct ProfileView: View {
    @ObservedObject var activityStore: ActivityStore
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        Text("Syntrak User")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 20)
                    
                    // Stats Cards
                    VStack(spacing: 16) {
                        StatCard(
                            title: "Total Activities",
                            value: "\(activityStore.activities.count)",
                            icon: "figure.run",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Total Distance",
                            value: formatDistance(activityStore.totalDistance),
                            icon: "ruler",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Total Time",
                            value: formatDuration(activityStore.totalDuration),
                            icon: "clock",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Recent Activities
                    if !activityStore.activities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Activities")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(Array(activityStore.activities.prefix(5))) { activity in
                                NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                    ActivityRowView(activity: activity)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Profile")
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

