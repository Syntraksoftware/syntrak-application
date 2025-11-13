import SwiftUI

struct SignUpView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
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
                .ignoresSafeArea(edges: .all)
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo
                        Image("white_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .padding(.top, 40)
                        
                        // App Name
                        Text("Syntrak")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Sign up text
                        Text("Create Your Account")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        // Sign Up Form
                        VStack(spacing: 20) {
                            // Name field
                            TextField("Full Name", text: $name)
                                .customTextFieldStyle()
                                .autocapitalization(.words)
                            
                            // Email field
                            TextField("Email", text: $email)
                                .customTextFieldStyle()
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            // Password field
                            SecureField("Password", text: $password)
                                .customTextFieldStyle()
                            
                            // Confirm Password field
                            SecureField("Confirm Password", text: $confirmPassword)
                                .customTextFieldStyle()
                            
                            // Error message
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                            
                            // Sign up button
                            Button(action: handleSignUp) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign Up")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                            .buttonStyle(CustomButtonStyle(backgroundColor: .white.opacity(0.2)))
                            .disabled(isLoading)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                        
                        // Login link
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.white.opacity(0.8))
                            Button("Login") {
                                dismiss()
                            }
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func handleSignUp() {
        errorMessage = nil
        
        // Validate passwords match
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        isLoading = true
        
        authManager.signUp(email: email, password: password, name: name) { success, error in
            isLoading = false
            if success {
                dismiss()
            } else {
                errorMessage = error ?? "Sign up failed. Please try again."
            }
        }
    }
}

