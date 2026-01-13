//
//  SignUpView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 1/7/26.
//  User profile creation view
//

import SwiftUI

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showAlert = false
    
    var onNavigateToLogin: () -> Void
    
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
                        Text("Create Account")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundColor(.blue)
                        
                        Text("Join us in your prayer journey")
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Form fields
                    VStack(spacing: 20) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TextField("Enter your full name", text: $name)
                                .textContentType(.name)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
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
                            
                            SecureField("Create a password (min 6 characters)", text: $password)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Confirm password field
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
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    // Status messages
                    if let error = errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal, 30)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let success = successMessage {
                        Text(success)
                            .font(.footnote)
                            .foregroundColor(.green)
                            .padding(.horizontal, 30)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Create Account button
                    Button(action: handleSignup) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 200, height: 50)
                        } else {
                            Text("Create Account")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                        }
                    }
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(25)
                    .disabled(!isFormValid || isLoading)
                    .padding(.top, 10)
                    
                    // Sign in link
                    Button(action: onNavigateToLogin) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.gray)
                            Text("Sign In")
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
        .alert(successMessage != nil ? "Success" : "Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                if successMessage != nil {
                    // After showing success, navigate to login
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onNavigateToLogin()
                    }
                }
            }
        } message: {
            Text(successMessage ?? errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let passwordsMatch = password == confirmPassword
        
        return emailValid && passwordValid && nameValid && passwordsMatch
    }
    
    // MARK: - Actions
    
    private func handleSignup() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        AuthService.shared.createUser(email: email.lowercased(), password: password, name: name) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let user):
                    // Account created but inactive - need to verify email
                    if user.status == "inactive" {
                        successMessage = "Account created! Please check your email to verify your account."
                        showAlert = true
                    } else {
                        // If account is active, show success
                        successMessage = "Account created successfully! Please sign in."
                        showAlert = true
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
        showAlert = true
    }
}

// MARK: - Preview

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView(onNavigateToLogin: {})
    }
}
