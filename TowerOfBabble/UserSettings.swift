//
//  UserSettings.swift
//  TowerOfBabble
//
//  Refactored to be the single source of truth for all user settings
//  Manages user preferences, syncs with backend via SettingsAPIService
//

import Foundation
import Combine

// MARK: - User Settings Model

struct UserSettingsModel: Codable {
    var voiceIndex: Int
    var playbackRate: Float  // Stored in DB but not currently used in UI
    
    static let defaultSettings = UserSettingsModel(
        voiceIndex: 0,
        playbackRate: 0.5
    )
}

// MARK: - User Settings Manager

class UserSettings: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = UserSettings()
    
    // MARK: - Published Properties
    
    @Published var settings: UserSettingsModel = .defaultSettings
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let apiService = SettingsAPIService.shared
    private let defaults = UserDefaults.standard
    private let settingsKey = "userSettings"
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Settings Management
    
    /// Load settings from UserDefaults on app launch
    func loadSettings() {
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(UserSettingsModel.self, from: data) {
            self.settings = decoded
            print("💾 Loaded saved settings: voiceIndex=\(decoded.voiceIndex)")
        } else {
            print("💾 No saved settings found, using defaults")
            self.settings = .defaultSettings
        }
    }
    
    /// Save settings to UserDefaults
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: settingsKey)
            print("💾 Settings saved to UserDefaults")
        }
    }
    
    /// Sync settings from User object (called after login)
    func syncFromUser(_ user: User) {
        self.settings = UserSettingsModel(
            voiceIndex: user.settings.voiceIndex,
            playbackRate: user.settings.playbackRate
        )
        saveSettings()
        print("✅ Settings synced from user object")
    }
    
    // MARK: - Update Settings
    
    /// Update voice index and sync to backend
    func updateVoiceIndex(_ index: Int, completion: ((Result<Void, SettingsAPIError>) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.updateSettings(voiceIndex: index) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let user):
                    // Update local settings from backend response
                    self.settings.voiceIndex = user.settings.voiceIndex
                    self.settings.playbackRate = user.settings.playbackRate
                    self.saveSettings()
                    
                    print("✅ Voice index updated to \(index)")
                    completion?(.success(()))
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("❌ Failed to update voice index: \(error)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    /// Update playback rate (for future use)
    func updatePlaybackRate(_ rate: Float, completion: ((Result<Void, SettingsAPIError>) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.updateSettings(playbackRate: rate) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let user):
                    self.settings.voiceIndex = user.settings.voiceIndex
                    self.settings.playbackRate = user.settings.playbackRate
                    self.saveSettings()
                    
                    print("✅ Playback rate updated to \(rate)")
                    completion?(.success(()))
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("❌ Failed to update playback rate: \(error)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get current voice index
    var currentVoiceIndex: Int {
        return settings.voiceIndex
    }
    
    /// Reset to default settings
    func resetToDefaults() {
        settings = .defaultSettings
        saveSettings()
        print("🔄 Settings reset to defaults")
    }
}
