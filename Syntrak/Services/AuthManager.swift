import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let userDefaultsKey = "isAuthenticated"
    private let userKey = "currentUser"
    
    init() {
        // Check if user is already logged in
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        isAuthenticated = UserDefaults.standard.bool(forKey: userDefaultsKey)
        
        if isAuthenticated {
            // Load user data if available
            if let userData = UserDefaults.standard.data(forKey: userKey),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
            }
        }
    }
    
    func signUp(email: String, password: String, name: String, completion: @escaping (Bool, String?) -> Void) {
        // TODO: Implement actual backend signup
        // For now, simulate signup
        
        // Validate input
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            completion(false, "Please fill in all fields")
            return
        }
        
        guard email.contains("@") else {
            completion(false, "Please enter a valid email address")
            return
        }
        
        guard password.count >= 6 else {
            completion(false, "Password must be at least 6 characters")
            return
        }
        
        // Simulate successful signup
        let user = User(id: UUID().uuidString, email: email, name: name)
        currentUser = user
        
        // Save to UserDefaults
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        
        isAuthenticated = true
        completion(true, nil)
    }
    
    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        // TODO: Implement actual backend login
        // For now, simulate login
        
        // Validate input
        guard !email.isEmpty, !password.isEmpty else {
            completion(false, "Please fill in all fields")
            return
        }
        
        // Simulate successful login
        // In real app, this would check against backend
        let user = User(id: UUID().uuidString, email: email, name: "User")
        currentUser = user
        
        // Save to UserDefaults
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        
        isAuthenticated = true
        completion(true, nil)
    }
    
    func logout() {
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }
}

struct User: Codable {
    let id: String
    let email: String
    let name: String
}

