import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Blue gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue,
                        Color.blue.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Logo
                    Image("white_logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                    
                    // App Name
                    Text("Syntrak")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Welcome text
                    Text("Welcome Back")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    // Login Form
                    VStack(spacing: 20) {
                        // Email field
                        TextField("Email", text: $email)
                            .customTextFieldStyle()
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        // Password field
                        SecureField("Password", text: $password)
                            .customTextFieldStyle()
                        
                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        // Login button
                        Button(action: handleLogin) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Login")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .buttonStyle(CustomButtonStyle(backgroundColor: .white.opacity(0.2)))
                        .disabled(isLoading)
                        
                        // Sign up link
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.white.opacity(0.8))
                            Button("Sign Up") {
                                showSignUp = true
                            }
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignUp) {
                SignUpView(authManager: authManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func handleLogin() {
        errorMessage = nil
        isLoading = true
        
        authManager.login(email: email, password: password) { success, error in
            isLoading = false
            if success {
                // Navigation handled by authManager state change
            } else {
                errorMessage = error ?? "Login failed. Please try again."
            }
        }
    }
}

struct CustomTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
            .foregroundColor(.white)
            .accentColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func customTextFieldStyle() -> some View {
        modifier(CustomTextFieldStyle())
    }
}

struct CustomButtonStyle: ButtonStyle {
    let backgroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
