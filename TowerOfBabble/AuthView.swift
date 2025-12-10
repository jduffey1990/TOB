//
//  AuthView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/8/25.
//

import SwiftUI

struct AuthView: View {
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var onAuthSuccess: () -> Void
    
    var body: some View {
        ZStack {
            // Same gradient as splash
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 10) {
                        Text(isLoginMode ? "Welcome Back" : "Create Account")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundColor(.blue)
                        
                        Text(isLoginMode ? "Sign in to continue your prayer journey" : "Begin your journey with prayer")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Name field (signup only)
                        if !isLoginMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Name")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                TextField("John Doe", text: $name)
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TextField("your.email@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            SecureField("Enter password", text: $password)
                                .textContentType(isLoginMode ? .password : .newPassword)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Confirm password (signup only)
                        if !isLoginMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                SecureField("Re-enter password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal, 30)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Submit button
                    Button(action: handleSubmit) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 200, height: 50)
                        } else {
                            Text(isLoginMode ? "Sign In" : "Create Account")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                        }
                    }
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(25)
                    .disabled(!isFormValid || isLoading)
                    .padding(.top, 10)
                    
                    // Toggle mode
                    Button(action: {
                        withAnimation {
                            isLoginMode.toggle()
                            errorMessage = nil
                            clearFields()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isLoginMode ? "Don't have an account?" : "Already have an account?")
                                .foregroundColor(.gray)
                            Text(isLoginMode ? "Sign Up" : "Sign In")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        
        if isLoginMode {
            return emailValid && passwordValid
        } else {
            let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty
            let passwordsMatch = password == confirmPassword
            return emailValid && passwordValid && nameValid && passwordsMatch
        }
    }
    
    private func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
        name = ""
    }
    
    // MARK: - Actions
    
    private func handleSubmit() {
        guard isFormValid else { return }
        
        if isLoginMode {
            login()
        } else {
            signup()
        }
    }
    
    private func login() {
        isLoading = true
        errorMessage = nil
        
        AuthService.shared.login(email: email.lowercased(), password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    // Save token and user data
                    UserDefaults.standard.set(response.token, forKey: "authToken")
                    UserDefaults.standard.set(response.user.id, forKey: "userId")
                    UserDefaults.standard.set(response.user.email, forKey: "userEmail")
                    UserDefaults.standard.set(response.user.name, forKey: "userName")
                    
                    print("Login successful: \(response.user.name)")
                    onAuthSuccess()
                    
                case .failure(let error):
                    handleError(error)
                }
            }
        }
    }
    
    private func signup() {
        isLoading = true
        errorMessage = nil
        
        AuthService.shared.createUser(email: email.lowercased(), password: password, name: name) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let user):
                    // Account created but inactive - need to verify email
                    if user.status == "inactive" {
                        errorMessage = "Account created! Please check your email to verify your account."
                        // Could also show a success message and prompt to check email
                    } else {
                        // If account is active, show success
                        errorMessage = "Account created successfully! Please sign in."
                    }
                    
                    // Switch to login mode after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isLoginMode = true
                            password = ""
                            confirmPassword = ""
                        }
                    }
                    
                case .failure(let error):
                    handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: AuthError) {
        switch error {
        case .invalidCredentials:
            errorMessage = "Invalid email or password"
        case .userInactive:
            errorMessage = "Please verify your email to activate your account"
        case .networkError(let message):
            errorMessage = "Network error: \(message)"
        case .serverError(let message):
            errorMessage = message
        case .decodingError:
            errorMessage = "Error processing server response"
        case .unknown:
            errorMessage = "An unexpected error occurred"
        }
    }
}

// MARK: - Preview

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView(onAuthSuccess: {})
    }
}
