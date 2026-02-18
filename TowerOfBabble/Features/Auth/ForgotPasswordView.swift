//
//  ForgotPasswordView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 1/7/26.
//  Password reset flow view
//

import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
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
                        Text("Reset Password")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundColor(.blue)
                        
                        Text("Enter your email to receive a password reset link")
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 80)
                    
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
                    .padding(.horizontal, 30)
                    .padding(.top, 40)
                    
                    // Status messages
                    if let error = errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.horizontal, 30)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let success = successMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text(success)
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .padding(.horizontal, 30)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 10)
                    }
                    
                    // Send Reset Link button
                    Button(action: handlePasswordReset) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 200, height: 50)
                        } else {
                            Text("Send Reset Link")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                        }
                    }
                    .background(isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(25)
                    .disabled(!isFormValid || isLoading)
                    .padding(.top, 20)
                    
                    // Back to login link
                    Button(action: onNavigateToLogin) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14))
                            Text("Back to Sign In")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        return emailValid
    }
    
    // MARK: - Actions
    
    private func handlePasswordReset() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        AuthService.shared.requestPasswordReset(email: email.lowercased()) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let message):
                    successMessage = message
                    
                case .failure(let error):
                    handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: AuthError) {
        switch error {
        case .networkError(let message):
            errorMessage = "Network error: \(message)"
        case .serverError(let message):
            errorMessage = message
        default:
            errorMessage = "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Preview

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView(onNavigateToLogin: {})
    }
}

