//
//  LoginView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 1/7/26.
//  Clean login-only view
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var onLoginSuccess: () -> Void
    var onNavigateToSignup: () -> Void
    var onNavigateToForgotPassword: () -> Void
    
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
                        Text("Welcome Back")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundColor(.blue)
                        
                        Text("Sign in to continue your prayer journey")
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Form fields
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TextField("Enter your email", text: $email)
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
                            
                            SecureField("Enter your password", text: $password)
                                .textContentType(.password)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    // Forgot password link
                    Button(action: onNavigateToForgotPassword) {
                        Text("Forgot Password?")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 5)
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal, 30)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Login button
                    Button(action: handleLogin) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 200, height: 50)
                        } else {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                        }
                    }
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(25)
                    .disabled(!isFormValid || isLoading)
                    .padding(.top, 10)
                    
                    // Sign up link
                    Button(action: onNavigateToSignup) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.gray)
                            Text("Sign Up")
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
        .alert("Login Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        return emailValid && passwordValid
    }
    
    // MARK: - Actions
    
    private func handleLogin() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        AuthService.shared.login(email: email.lowercased(), password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    AuthManager.shared.login(token: response.token, user: response.user)
                    onLoginSuccess()
                    
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
        showError = true
    }
}

// MARK: - Preview

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(
            onLoginSuccess: {},
            onNavigateToSignup: {},
            onNavigateToForgotPassword: {}
        )
    }
}
