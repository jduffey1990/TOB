//
//  TowerOfBabbleApp.swift
//  TowerOfBabble
//
//  Updated to use MainTabView with bottom navigation
//

import SwiftUI

@main
struct TowerOfBabbleApp: App {
    // ✅ Observe the singleton AuthManager
    @StateObject private var authManager = AuthManager.shared
    
    // ✅ Keep your splash screen animation
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    // Show splash screen first
                    SplashView {
                        withAnimation {
                            showSplash = false
                        }
                    }
                } else {
                    // After splash, show main app or login based on auth state
                    if authManager.isAuthenticated {
                        MainTabView()
                            .transition(.opacity)
                    } else {
                        AuthView(onAuthSuccess: {
                            // Auth state automatically updates via @Published
                            // No need to manually set isAuthenticated
                        })
                        .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .onReceive(NotificationCenter.default.publisher(for: .sessionExpired)) { _ in
                // Optional: Show alert when session expires
                print("⚠️ Session expired - user logged out")
                // Could show an alert here if desired
            }
        }
    }
}

