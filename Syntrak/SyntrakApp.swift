import SwiftUI

@main
struct SyntrakApp: App {
    @StateObject private var activityStore = ActivityStore()
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView(showSplash: $showSplash)
            } else {
                HomeView(activityStore: activityStore)
            }
        }
    }
}

