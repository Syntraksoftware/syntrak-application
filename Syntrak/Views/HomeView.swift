import SwiftUI

struct HomeView: View {
    @ObservedObject var activityStore: ActivityStore
    @ObservedObject var authManager: AuthManager
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
            
            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }
                .tag(2)
            
            RoutesView()
                .tabItem {
                    Label("Routes", systemImage: "map")
                }
                .tag(3)
            
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
                .tag(4)
            
            CoachingView()
                .tabItem {
                    Label("Coaching", systemImage: "person.2")
                }
                .tag(5)
            
            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.3")
                }
                .tag(6)
            
            ProfileView(activityStore: activityStore, authManager: authManager)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(7)
        }
    }
}

