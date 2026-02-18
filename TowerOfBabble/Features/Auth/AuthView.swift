//
//  AuthView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/8/25.
//
//  AuthView.swift
//  TowerOfBabble
//
//  Router view for authentication flow
//

import SwiftUI

enum AuthScreen {
    case login
    case signup
    case forgotPassword
}

struct AuthView: View {
    @State private var currentScreen: AuthScreen = .login
    var onAuthSuccess: () -> Void
    
    var body: some View {
        ZStack {
            switch currentScreen {
            case .login:
                LoginView(
                    onLoginSuccess: onAuthSuccess,
                    onNavigateToSignup: {
                        withAnimation {
                            currentScreen = .signup
                        }
                    },
                    onNavigateToForgotPassword: {
                        withAnimation {
                            currentScreen = .forgotPassword
                        }
                    }
                )
                .transition(.opacity)
                
            case .signup:
                SignupView(
                    onNavigateToLogin: {
                        withAnimation {
                            currentScreen = .login
                        }
                    }
                )
                .transition(.opacity)
                
            case .forgotPassword:
                ForgotPasswordView(
                    onNavigateToLogin: {
                        withAnimation {
                            currentScreen = .login
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Preview

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView(onAuthSuccess: {})
    }
}
