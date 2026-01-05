//
//  VoiceService.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 1/5/26.
//
//  Refactored from VoiceManager to be a pure voice API service
//  Handles voice fetching, availability checking, and voice metadata
//  Does NOT manage user settings (that's UserSettings.shared)
//

import Foundation
import AVFoundation

// MARK: - Voice Models

struct VoiceOption: Codable {
    let id: String
    let name: String
    let language: String
    let gender: String
    let description: String
    let tier: String
    let provider: String  // "apple", "azure", "fishaudio"
}

struct VoicesResponse: Codable {
    let userTier: String
    let availableVoices: [VoiceOption]
    let allVoices: [VoiceOption]
    let count: VoiceCount
}

struct VoiceCount: Codable {
    let available: Int
    let total: Int
}

// MARK: - Voice Service

class VoiceService {
    
    // MARK: - Singleton
    
    static let shared = VoiceService()
    
    // MARK: - Properties
    
    private let apiService = PrayerAPIService.shared
    
    // Cached voice data (refreshed on fetch)
    private(set) var availableVoices: [VoiceOption] = []
    private(set) var allVoices: [VoiceOption] = []
    private(set) var userTier: String = "free"
    
    // MARK: - Initialization
    
    private init() {
        // Service doesn't auto-fetch on init
        // Views/managers call fetchVoices() when needed
    }
    
    // MARK: - Voice Fetching
    
    /// Fetch available voices from backend
    func fetchVoices(completion: ((Result<VoicesResponse, PrayerAPIError>) -> Void)? = nil) {
        apiService.fetchVoices { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let voicesResponse):
                    self?.availableVoices = voicesResponse.availableVoices
                    self?.allVoices = voicesResponse.allVoices
                    self?.userTier = voicesResponse.userTier
                    
                    print("✅ Fetched \(voicesResponse.availableVoices.count)/\(voicesResponse.allVoices.count) voices")
                    print("   User tier: \(voicesResponse.userTier)")
                    
                    completion?(.success(voicesResponse))
                    
                case .failure(let error):
                    print("❌ Failed to fetch voices: \(error)")
                    
                    // Fallback to Apple voices if backend fails
                    self?.loadAppleVoicesAsFallback()
                    
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Voice Selection & Queries
    
    /// Get voice by index (uses current voiceIndex from UserSettings)
    func getCurrentVoice() -> VoiceOption? {
        let index = UserSettings.shared.currentVoiceIndex
        return getVoiceByIndex(index)
    }
    
    /// Get voice by specific index
    func getVoiceByIndex(_ index: Int) -> VoiceOption? {
        guard index >= 0 && index < availableVoices.count else {
            print("⚠️ Voice index \(index) out of range (0..<\(availableVoices.count))")
            return nil
        }
        return availableVoices[index]
    }
    
    /// Get voice display names for picker UI
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
        switch voice.tier.lowercased() {
        case "pro":
            return "This voice requires a Pro subscription"
        case "warrior", "lifetime":
            return "This voice requires a Prayer Warrior subscription"
        default:
            return "This voice is not available in your current plan"
        }
    }
    
    /// Get tier badge info for UI
    func getTierBadge(for voiceIndex: Int) -> (text: String, color: String)? {
        if voiceIndex > 2 && voiceIndex <= 5 {
            return ("• Pro", "blue")
        } else if voiceIndex > 5 {
            return ("• Warrior", "purple")
        }
        return nil
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
    
    // MARK: - Voice Preview (Optional for future use)
    
    /// Preview text for voice testing
    let previewText = "The Lord is my shepherd; I shall not want."
}
