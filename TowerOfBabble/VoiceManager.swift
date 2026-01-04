//
//  VoiceManager.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 1/4/26.
//  Handles voice selection, settings, and voice availability
//

import Foundation
import AVFoundation
import Combine

// MARK: - Voice Manager

class VoiceManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var availableVoices: [VoiceOption] = []
    @Published var allVoices: [VoiceOption] = []
    @Published var userTier: String = "free"
    @Published var settings: UserSettings = .defaultSettings
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let apiService = PrayerAPIService.shared
    private let defaults = UserDefaults.standard
    private let settingsKey = "userSettings"
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        fetchVoices()
    }
    
    // MARK: - Settings Management
    
    func loadSettings() {
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            self.settings = decoded
            print("💾 Loaded saved settings: voice=\(decoded.voiceIndex)")
        } else {
            print("💾 No saved settings found, using defaults")
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: settingsKey)
            print("💾 Settings saved")
        }
    }
    
    func updateVoiceIndex(_ index: Int) {
        settings.voiceIndex = index
        saveSettings()
    }
    
    // MARK: - Voice Fetching
    
    func fetchVoices(completion: ((Result<VoicesResponse, PrayerAPIError>) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.fetchVoices { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let voicesResponse):
                    self?.availableVoices = voicesResponse.availableVoices
                    self?.allVoices = voicesResponse.allVoices
                    self?.userTier = voicesResponse.userTier
                    
                    print("✅ Fetched \(voicesResponse.availableVoices.count)/\(voicesResponse.allVoices.count) voices")
                    print("   User tier: \(voicesResponse.userTier)")
                    
                    completion?(.success(voicesResponse))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to fetch voices: \(error)")
                    
                    // Fallback to Apple voices if backend fails
                    self?.loadAppleVoicesAsFallback()
                    
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Voice Selection
    
    /// Get currently selected voice
    var currentVoice: VoiceOption? {
        return getVoiceByIndex(settings.voiceIndex)
    }
    
    /// Get voice by index
    func getVoiceByIndex(_ index: Int) -> VoiceOption? {
        guard index >= 0 && index < availableVoices.count else {
            return nil
        }
        return availableVoices[index]
    }
    
    /// Get voice display names for picker
    func getVoiceDisplayNames() -> [String] {
        return availableVoices.map { voice in
            "\(voice.name) (\(voice.provider.capitalized))"
        }
    }
    
    /// Check if a voice is locked (requires upgrade)
    func isVoiceLocked(_ voice: VoiceOption) -> Bool {
        return !availableVoices.contains(where: { $0.id == voice.id })
    }
    
    /// Get upgrade message for locked voice
    func getUpgradeMessage(for voice: VoiceOption) -> String {
        switch voice.tier {
        case "pro":
            return "This voice requires a Pro subscription"
        case "warrior":
            return "This voice requires a Prayer Warrior subscription"
        default:
            return "This voice is not available in your current plan"
        }
    }
    
    // MARK: - Fallback Apple Voices
    
    /// Load Apple voices as fallback if backend fails
    private func loadAppleVoicesAsFallback() {
        let appleVoices = getAppleVoices()
        
        availableVoices = appleVoices.map { avVoice in
            VoiceOption(
                id: avVoice.identifier,
                name: avVoice.name,
                language: avVoice.language,
                gender: inferGender(from: avVoice.name),
                description: "Apple \(avVoice.name)",
                tier: "free",
                provider: "apple"
            )
        }
        
        allVoices = availableVoices
        userTier = "free"
        
        print("⚠️ Using Apple voices as fallback (\(availableVoices.count) voices)")
    }
    
    /// Get high-quality Apple voices
    private func getAppleVoices() -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Allowlist of known high-quality voices
        let allowedVoiceNames = [
            "Samantha",    // Natural female (Enhanced)
            "Alex",        // Default male (Enhanced)
            "Moira",       // Irish female (Enhanced)
            "Daniel",      // British male (Enhanced)
            "Karen",       // Australian female (Enhanced)
            "Tessa",       // South African female (Enhanced)
        ]
        
        let voices = allVoices.filter { voice in
            guard voice.language.hasPrefix("en-") else { return false }
            return allowedVoiceNames.contains(voice.name)
        }
        
        let sortedVoices = voices.sorted { voice1, voice2 in
            // Sort by quality first, then name
            if voice1.quality != voice2.quality {
                return voice1.quality.rawValue > voice2.quality.rawValue
            }
            return voice1.name < voice2.name
        }
        
        print("📢 Available Apple Voices (\(sortedVoices.count)):")
        for (index, voice) in sortedVoices.enumerated() {
            let qualityString: String
            switch voice.quality {
            case .default: qualityString = "Default"
            case .enhanced: qualityString = "Enhanced ⭐"
            case .premium: qualityString = "Premium ⭐⭐"
            @unknown default: qualityString = "Unknown"
            }
            print("  [\(index)] \(voice.name) (\(voice.language)) - \(qualityString)")
        }
        
        // Fallback to any enhanced English voices if allowlist returns nothing
        if sortedVoices.isEmpty {
            print("⚠️ No allowlisted voices found, falling back to enhanced voices")
            return allVoices.filter { voice in
                voice.language.hasPrefix("en-") && voice.quality == .enhanced
            }.sorted { $0.name < $1.name }
        }
        
        return sortedVoices
    }
    
    /// Infer gender from voice name (rough heuristic)
    private func inferGender(from name: String) -> String {
        let femaleNames = ["Samantha", "Moira", "Karen", "Tessa", "Victoria", "Kate", "Serena"]
        let maleNames = ["Alex", "Daniel", "Tom", "Fred"]
        
        if femaleNames.contains(name) {
            return "female"
        } else if maleNames.contains(name) {
            return "male"
        } else {
            return "neutral"
        }
    }
    
    // MARK: - Voice Preview (Optional)
    
    /// Preview text for voice testing
    let previewText = "The Lord is my shepherd; I shall not want."
    
    // You can add a preview method here if needed
    // func previewVoice(_ voice: VoiceOption) { ... }
}
