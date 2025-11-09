import SwiftUI

struct HomeView: View {
    @ObservedObject var activityStore: ActivityStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ActivityListView(activityStore: activityStore)
                .tabItem {
                    Label("Activities", systemImage: "list.bullet")
                }
                .tag(0)
            
            RecordActivityView(activityStore: activityStore)
                .tabItem {
                    Label("Record", systemImage: "record.circle")
                }
                .tag(1)
            
            ProfileView(activityStore: activityStore)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(2)
        }
    }
}

