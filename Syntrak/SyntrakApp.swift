import SwiftUI

@main
struct SyntrakApp: App {
    @StateObject private var activityStore = ActivityStore()
    
    var body: some Scene {
        WindowGroup {
            HomeView(activityStore: activityStore)
        }
    }
}

