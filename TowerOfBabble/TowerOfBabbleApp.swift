import SwiftUI

@main
struct TowerOfBabbleApp: App {
    @State private var showSplash = true
    @State private var isAuthenticated = false
    
    init() {
        // Check if user is already logged in
        _isAuthenticated = State(initialValue: AuthService.shared.isLoggedIn())
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView {
                        withAnimation {
                            showSplash = false
                        }
                    }
                } else {
                    if isAuthenticated {
                        PrayersListView()
                    } else {
                        AuthView {
                            withAnimation {
                                isAuthenticated = true
                            }
                        }
                    }
                }
            }
        }
    }
}
