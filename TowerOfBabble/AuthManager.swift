//
//  AuthManager.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/17/25.
//  Centralized authentication state management
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    // MARK: - Singleton
    static let shared = AuthManager()
    
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    
    // MARK: - Private Properties
    private var authToken: String?
    
    // UserDefaults keys
    private let tokenKey = "authToken"
    private let userIdKey = "userId"
    private let userEmailKey = "userEmail"
    private let userNameKey = "userName"
    private let userStatusKey = "userStatus"
    private let userTierKey = "userTier"
    private let userSubscriptionExpiresAtKey = "userSubscriptionExpiresAt"

    
    // MARK: - Initialization
    private init() {
        loadAuthState()
    }
    
    // MARK: - Auth State Management
    
    /// Load saved authentication state from UserDefaults on app launch
    private func loadAuthState() {
        guard let token = UserDefaults.standard.string(forKey: tokenKey),
              let userId = UserDefaults.standard.string(forKey: userIdKey),
              let email = UserDefaults.standard.string(forKey: userEmailKey),
              let name = UserDefaults.standard.string(forKey: userNameKey) else {
            print("ℹ️ No saved auth state found")
            return
        }
        
        // Load user with settings from PrayerManager (which loads from UserDefaults)
        let status = UserDefaults.standard.string(forKey: userStatusKey) ?? "active"
        let tier = UserDefaults.standard.string(forKey: userTierKey) ?? "free"
        let subscriptionExpiresAt = UserDefaults.standard.string(forKey: userSubscriptionExpiresAtKey)
        
        // PrayerManager will load the same settings when it initializes
        var loadedSettings = UserSettings.defaultSettings
        if let settingsData = UserDefaults.standard.data(forKey: "userSettings"),
           let decodedSettings = try? JSONDecoder().decode(UserSettings.self, from: settingsData) {
            loadedSettings = decodedSettings
        }
        
        self.authToken = token
        self.currentUser = User(
            id: userId,
            email: email,
            name: name,
            status: status,
            subscriptionTier: tier,
            subscriptionExpiresAt: subscriptionExpiresAt,
            settings: loadedSettings, // Load from PrayerManager
            createdAt: "",
            updatedAt: ""
        )
        self.isAuthenticated = true
        
        print("✅ Loaded auth state for user: \(email)")
    }
    
    /// Save authentication data after successful login
    func login(token: String, user: User) {
        // Save to UserDefaults
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(user.id, forKey: userIdKey)
        UserDefaults.standard.set(user.email, forKey: userEmailKey)
        UserDefaults.standard.set(user.name, forKey: userNameKey)
        UserDefaults.standard.set(user.status, forKey: userStatusKey)
        UserDefaults.standard.set(user.subscriptionTier, forKey: userTierKey)
        if let expiresAt = user.subscriptionExpiresAt {
            UserDefaults.standard.set(expiresAt, forKey: userSubscriptionExpiresAtKey)
        }
        
        // ✅ Load user's settings from backend into VoiceManager
        VoiceManager.shared.settings = user.settings
        VoiceManager.shared.saveSettings() // This saves to UserDefaults under "userSettings"
        
        // Update in-memory state
        self.authToken = token
        self.currentUser = user
        self.isAuthenticated = true
        
        print("✅ User logged in: \(user.email)")
    }
    
    /// Clear all authentication data and cached content
    func logout() {
        print("🔓 Logging out user: \(currentUser?.email ?? "unknown")")
        
        // Clear auth data
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userStatusKey)
        UserDefaults.standard.removeObject(forKey: userTierKey)
        UserDefaults.standard.removeObject(forKey: userSubscriptionExpiresAtKey)
        
        // Clear cached data to prevent data leakage between users
        UserDefaults.standard.removeObject(forKey: "cachedPrayers")
        UserDefaults.standard.removeObject(forKey: "cachedPrayOnItItems")
        UserDefaults.standard.removeObject(forKey: "userSettings") // Clear settings too
        
        // Update in-memory state
        self.authToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
        
        print("✅ User logged out successfully")
    }

    
    /// Handle 401 Unauthorized responses from backend (token expired/invalid)
    func handleTokenExpired() {
        print("⚠️ Token expired or invalid (401 from backend)")
        logout()
        
        // Post notification so UI can show an alert if desired
        NotificationCenter.default.post(
            name: NSNotification.Name("SessionExpired"),
            object: nil
        )
    }
    
    // MARK: - Token Access
    
    /// Get the current authentication token for API requests
    func getToken() -> String? {
        return authToken
    }
    
    /// Check if user is currently logged in
    var isLoggedIn: Bool {
        return authToken != nil && isAuthenticated
    }
}

// MARK: - Notification Names Extension
extension NSNotification.Name {
    static let sessionExpired = NSNotification.Name("SessionExpired")
}
