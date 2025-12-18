//
//  PrayerManager.swift
//  TowerOfBabble
//
//  Updated to use backend API instead of UserDefaults
//  Converted to singleton pattern for shared state across views
//  INCLUDES settings management for voice and playback
//

import Foundation
import AVFoundation
import Combine

// MARK: - Prayer Model (matches backend)
struct Prayer: Identifiable, Codable {
    let id: String  // ✅ String ID from backend (no UUID conversion)
    let userId: String
    var title: String
    var text: String
    let category: String?
    let isTemplate: Bool
    let playCount: Int
    let lastPlayedAt: String?
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    
    // Helper to get createdAt as Date for UI sorting if needed
    var createdDate: Date {
        ISO8601DateFormatter().date(from: createdAt) ?? Date()
    }
}

class PrayerManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // MARK: - Singleton
    static let shared = PrayerManager()
    
    // MARK: - Published Properties
    @Published var prayers: [Prayer] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var prayerStats: PrayerStatsResponse?
    @Published var isSpeaking: Bool = false
    @Published var settings: UserSettings = .defaultSettings
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private let apiService = PrayerAPIService.shared
    
    // Local cache key for offline support
    private let prayersKey = "cachedPrayers"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    private override init() {
        super.init()
        synthesizer.delegate = self
        loadSettings()
        loadPrayersFromCache()
        fetchPrayersFromAPI()
        fetchStats()
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    // MARK: - Settings Management
    
    func loadSettings() {
        if let data = defaults.data(forKey: "userSettings"),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            self.settings = decoded
            print("💾 Loaded saved settings: voice=\(decoded.voiceIndex), rate=\(decoded.playbackRate)")
        } else {
            print("💾 No saved settings found, using defaults")
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: "userSettings")
            print("💾 Saved settings: voice=\(settings.voiceIndex), rate=\(settings.playbackRate)")
        }
    }
    
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("en-")
        }
        return voices
    }
    
    // MARK: - Prayer Stats
    
    var hasAICredits: Bool {
        return false
    }
    
    func fetchStats() {
        apiService.fetchPrayerStats { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stats):
                    self?.prayerStats = stats
                    print("✅ Stats: \(stats.prayers.current)/\(stats.prayers.limit ?? 0) prayers")
                    
                case .failure(let error):
                    print("⚠️ Failed to fetch stats: \(error.localizedDescription)")
                }
            }
        }
    }
    
    var prayerCountText: String {
        guard let stats = prayerStats else {
            return "\(prayers.count) prayers"
        }
        
        if let limit = stats.prayers.limit {
            return "\(stats.prayers.current)/\(limit) prayers"
        } else {
            return "\(stats.prayers.current) prayers (unlimited)"
        }
    }
    
    var canCreateMorePrayers: Bool {
        guard let stats = prayerStats else {
            return true
        }
        return stats.prayers.canCreate
    }
    
    // MARK: - Fetch Prayers from API
    
    func fetchPrayersFromAPI() {
        isLoading = true
        errorMessage = nil
        
        apiService.fetchPrayers { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let prayers):
                    self?.prayers = prayers  // ✅ No conversion needed!
                    self?.savePrayersToCache()
                    print("✅ Loaded \(prayers.count) prayers from API")
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to fetch prayers: \(error.localizedDescription)")
                    
                    if self?.prayers.isEmpty == true {
                        self?.loadPrayersFromCache()
                    }
                }
            }
        }
    }
    
    // MARK: - Create Prayer
    
    func addPrayer(title: String, text: String, completion: ((Result<Prayer, PrayerAPIError>) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.createPrayer(title: title, text: text) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let newPrayer):
                    self?.prayers.append(newPrayer)
                    self?.savePrayersToCache()
                    self?.fetchStats()
                    print("✅ Prayer created")
                    completion?(.success(newPrayer))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to create prayer: \(error.localizedDescription)")
                    
                    if case .limitReached = error {
                        self?.fetchStats()
                    }
                    
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Update Prayer
    
    func updatePrayer(_ prayer: Prayer, completion: ((Result<Prayer, PrayerAPIError>) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.updatePrayer(
            id: prayer.id,  // ✅ Already a String!
            title: prayer.title,
            text: prayer.text,
            category: nil
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let updatedPrayer):
                    if let index = self?.prayers.firstIndex(where: { $0.id == prayer.id }) {
                        self?.prayers[index] = updatedPrayer
                        self?.savePrayersToCache()
                        print("✅ Prayer updated")
                    }
                    completion?(.success(updatedPrayer))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to update prayer: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Delete Prayer
    
    func deletePrayer(_ prayer: Prayer, completion: ((Result<Void, PrayerAPIError>) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.deletePrayer(id: prayer.id) { [weak self] result in  // ✅ Already a String!
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.prayers.removeAll { $0.id == prayer.id }
                    self?.savePrayersToCache()
                    self?.fetchStats()
                    print("✅ Prayer deleted")
                    completion?(.success(()))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to delete prayer: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Record Playback
    
    func recordPlayback(_ prayer: Prayer) {
        print("🎙️ Recording playback for prayer: \(prayer.id)")
        apiService.recordPlayback(id: prayer.id) { result in  // ✅ Already a String!
            switch result {
            case .success:
                print("✅ Playback recorded")
                
            case .failure(let error):
                print("⚠️ Failed to record playback: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Text-to-Speech
    
    // ✅ For playing saved prayers (records playback)
    func speakPrayer(_ prayer: Prayer) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        
        // Only record playback for saved prayers
        recordPlayback(prayer)
        
        let utterance = AVSpeechUtterance(string: prayer.text)
        
        let voices = getAvailableVoices()
        if settings.voiceIndex < voices.count {
            utterance.voice = voices[settings.voiceIndex]
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = Float(settings.playbackRate)
        
        synthesizer.speak(utterance)
    }
    
    //For previewing text without a saved prayer (no playback recording)
    func speakText(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        let voices = getAvailableVoices()
        if settings.voiceIndex < voices.count {
            utterance.voice = voices[settings.voiceIndex]
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = Float(settings.playbackRate)
        
        synthesizer.speak(utterance)
    }
    // MARK: - Local Cache
    
    private func savePrayersToCache() {
        if let encoded = try? JSONEncoder().encode(prayers) {
            defaults.set(encoded, forKey: prayersKey)
            print("💾 Cached \(prayers.count) prayers locally")
        }
    }
    
    private func loadPrayersFromCache() {
        if let data = defaults.data(forKey: prayersKey),
           let decoded = try? JSONDecoder().decode([Prayer].self, from: data) {
            prayers = decoded
            print("💾 Loaded \(prayers.count) prayers from cache")
        }
    }
    
    // MARK: - Manual Refresh
    
    func refresh() {
        fetchPrayersFromAPI()
        fetchStats()
    }
}






