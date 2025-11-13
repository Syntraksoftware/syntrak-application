import SwiftUI

@main
struct SyntrakApp: App {
    @StateObject private var activityStore = ActivityStore()
    @StateObject private var authManager = AuthManager()
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView(showSplash: $showSplash)
            } else if authManager.isAuthenticated {
                HomeView(activityStore: activityStore, authManager: authManager)
            } else {
                LoginView(authManager: authManager)
            }
        }
    }
}

