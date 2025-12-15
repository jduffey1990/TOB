//
//  PrayerManager.swift
//  TowerOfBabble
//
//  Updated to use backend API instead of UserDefaults
//

import Foundation
import AVFoundation
import Combine

// Model for a single prayer (local representation)
struct Prayer: Identifiable, Codable {
    let id: UUID
    var title: String
    var text: String
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, text: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
    }
}

class PrayerManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var prayers: [Prayer] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var prayerStats: PrayerStatsResponse?
    @Published var isSpeaking: Bool = false  // Now @Published for reactivity
    
    private let synthesizer = AVSpeechSynthesizer()
    private let apiService = PrayerAPIService.shared
    
    // Local cache key for offline support
    private let prayersKey = "cachedPrayers"
    private let defaults = UserDefaults.standard
    
    override init() {
        super.init()
        synthesizer.delegate = self  // Set delegate to receive callbacks
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
    
    // MARK: - Prayer Stats
    var hasAICredits: Bool {
        // TODO: Phase 3 - Check actual AI credits from backend
        // For now, return true so flow goes to AI builder
        return false
        
        // Future implementation:
        // return aiCreditsRemaining > 0
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
            return true // Assume yes if we don't have stats yet
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
                case .success(let prayerResponses):
                    let localPrayers = prayerResponses.map { $0.toLocalPrayer() }
                    self?.prayers = localPrayers
                    self?.savePrayersToCache()
                    print("✅ Loaded \(localPrayers.count) prayers from API")
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to fetch prayers: \(error.localizedDescription)")
                    
                    // If network fails, we still have cached prayers loaded
                    if self?.prayers.isEmpty == true {
                        self?.loadPrayersFromCache()
                    }
                }
            }
        }
    }
    
    // MARK: - Create Prayer
    
    func addPrayer(_ prayer: Prayer, completion: ((Result<Prayer, PrayerAPIError>) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.createPrayer(title: prayer.title, text: prayer.text) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let prayerResponse):
                    let newPrayer = prayerResponse.toLocalPrayer()
                    self?.prayers.append(newPrayer)
                    self?.savePrayersToCache()
                    self?.fetchStats() // Refresh stats after creating
                    print("✅ Prayer created")
                    completion?(.success(newPrayer))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to create prayer: \(error.localizedDescription)")
                    
                    // Special handling for limit reached
                    if case .limitReached = error {
                        self?.fetchStats() // Refresh stats to show accurate limits
                    }
                    
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Update Prayer
    
    func updatePrayer(_ prayer: Prayer) {
        isLoading = true
        errorMessage = nil
        
        apiService.updatePrayer(
            id: prayer.id.uuidString,
            title: prayer.title,
            text: prayer.text,
            category: nil
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let prayerResponse):
                    let updatedPrayer = prayerResponse.toLocalPrayer()
                    if let index = self?.prayers.firstIndex(where: { $0.id == prayer.id }) {
                        self?.prayers[index] = updatedPrayer
                        self?.savePrayersToCache()
                        print("✅ Prayer updated")
                    }
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to update prayer: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Delete Prayer
    
    func deletePrayer(_ prayer: Prayer) {
        isLoading = true
        errorMessage = nil
        
        apiService.deletePrayer(id: prayer.id.uuidString) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.prayers.removeAll { $0.id == prayer.id }
                    self?.savePrayersToCache()
                    self?.fetchStats() // Refresh stats after deleting
                    print("✅ Prayer deleted")
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to delete prayer: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Record Playback
    
    func recordPlayback(_ prayer: Prayer) {
        // Don't show loading for playback recording (it's a background operation)
        apiService.recordPlayback(id: prayer.id.uuidString) { result in
            switch result {
            case .success:
                print("✅ Playback recorded")
                
            case .failure(let error):
                print("⚠️ Failed to record playback: \(error.localizedDescription)")
                // Don't show error to user - this is not critical
            }
        }
    }
    
    // MARK: - Text-to-Speech
    
    func speakPrayer(_ prayer: Prayer) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        
        // Record playback in background
        recordPlayback(prayer)
        
        let utterance = AVSpeechUtterance(string: prayer.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
        // Note: isSpeaking will be set to true automatically by delegate callback
    }
    
    // MARK: - Local Cache (for offline support)
    
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
