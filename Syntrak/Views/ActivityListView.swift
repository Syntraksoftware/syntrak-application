import SwiftUI

struct ActivityListView: View {
    @ObservedObject var activityStore: ActivityStore
    
    var body: some View {
        NavigationView {
            List {
                if activityStore.activities.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No activities yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Start recording your first activity!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 100)
                } else {
                    ForEach(activityStore.activities) { activity in
                        NavigationLink(destination: ActivityDetailView(activity: activity)) {
                            ActivityRowView(activity: activity)
                        }
                    }
                    .onDelete(perform: deleteActivities)
                }
            }
            .navigationTitle("Syntrak")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteActivities(at offsets: IndexSet) {
        for index in offsets {
            activityStore.deleteActivity(activityStore.activities[index])
        }
    }
}

struct ActivityRowView: View {
    let activity: Activity
    
    var body: some View {
        HStack {
            Image(systemName: activity.type.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.type.rawValue)
                    .font(.headline)
                Text(activity.startTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(activity.formattedDistance)
                    .font(.headline)
                Text(activity.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

