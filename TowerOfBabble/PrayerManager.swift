//
//  PrayerManager.swift
//  TowerOfBabble
//
//  Refactored to focus purely on prayer management
//  Settings moved to UserSettings, voices moved to VoiceService
//

import Foundation
import Combine

// MARK: - Prayer Model

struct Prayer: Identifiable, Codable {
    let id: String  // String ID from backend
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
    
    // Helper to get createdAt as Date for UI sorting
    var createdDate: Date {
        ISO8601DateFormatter().date(from: createdAt) ?? Date()
    }
}

struct PrayerLimits: Codable {
    let current: Int
    let limit: Int?
}

struct AIGenerationLimits: Codable {
    let used: Int
    let limit: Int?
}

// MARK: - Prayer Manager

class PrayerManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PrayerManager()
    
    // MARK: - Published Properties
    
    @Published var prayers: [Prayer] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var prayerStats: PrayerStatsResponse?
    
    // MARK: - Private Properties
    private let audioPlayer = AudioPlayerManager.shared
    
    // MARK: - Initialization
    
    private let apiService = PrayerAPIService.shared
    private init() {
        loadPrayers()
        loadStats()
    }
    
    func fetchStats(completion: @escaping (Result<PrayerStatsResponse, PrayerAPIError>) -> Void) {
        apiService.fetchPrayerStats(completion: completion)
    }
    // MARK: - Prayer CRUD Operations
    
    func loadPrayers() {
        isLoading = true
        errorMessage = nil
        
        apiService.fetchPrayers { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let fetchedPrayers):
                    self?.prayers = fetchedPrayers.sorted { $0.createdDate > $1.createdDate }
                    print("✅ Loaded \(fetchedPrayers.count) prayers")
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to load prayers: \(error)")
                }
            }
        }
    }
    
    func addPrayer(title: String, text: String, completion: @escaping (Result<Prayer, PrayerAPIError>) -> Void) {
        apiService.createPrayer(title: title, text: text) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let prayer):
                    self?.prayers.insert(prayer, at: 0)
                    self?.loadStats() // Refresh stats after adding
                    completion(.success(prayer))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func updatePrayer(_ prayer: Prayer, completion: @escaping (Result<Prayer, PrayerAPIError>) -> Void) {
        apiService.updatePrayer(
            id: prayer.id,
            title: prayer.title,
            text: prayer.text,
            category: prayer.category
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedPrayer):
                    if let index = self?.prayers.firstIndex(where: { $0.id == updatedPrayer.id }) {
                        self?.prayers[index] = updatedPrayer
                    }
                    completion(.success(updatedPrayer))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func deletePrayer(_ prayer: Prayer, completion: @escaping (Result<Void, PrayerAPIError>) -> Void) {
        apiService.deletePrayer(id: prayer.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.prayers.removeAll { $0.id == prayer.id }
                    self?.loadStats() // Refresh stats after deleting
                    completion(.success(()))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    
    // MARK: - AI Prayer Generation

    func postPrompt(
        _ requestPayload: [String: Any],
        completion: ((Result<String, PrayerAPIError>) -> Void)? = nil
    ) {
        print("\n🟦 [PrayerManager] postPrompt called")
        print("   Payload keys: \(requestPayload.keys.joined(separator: ", "))")
        
        // Log payload details
        if let items = requestPayload["prayOnItItems"] as? [[String: Any]] {
            print("   📋 Pray On It Items: \(items.count)")
            items.forEach { item in
                if let name = item["name"] as? String {
                    print("      - \(name)")
                }
            }
        }
        
        if let type = requestPayload["prayerType"] as? String {
            print("   🙏 Prayer Type: \(type)")
        }
        
        if let tone = requestPayload["tone"] as? String {
            print("   🎵 Tone: \(tone)")
        }
        
        if let length = requestPayload["length"] as? String {
            print("   ⏱️  Length: \(length)")
        }
        
        if let expansiveness = requestPayload["expansiveness"] as? String {
            print("   📝 Expansiveness: \(expansiveness)")
        }
        
        if let context = requestPayload["customContext"], !(context is NSNull) {
            print("   💬 Has custom context: Yes")
        }
        
        isLoading = true
        errorMessage = nil
        
        apiService.createPrompt(requestPayload) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let generatedText):
                    print("✅ [PrayerManager] Prompt returned successfully")
                    print("   Generated text length: \(generatedText.count) characters")
                    print("   Preview: \(String(generatedText.prefix(100)))...")
                    completion?(.success(generatedText))
                    
                case .failure(let error):
                    print("❌ [PrayerManager] Prompt failed: \(error)")
                    self?.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Stats Management
    
    func loadStats() {
        apiService.fetchPrayerStats { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stats):
                    self?.prayerStats = stats
                    print("✅ Loaded prayer stats: \(stats.prayers.current)/\(stats.prayers.limit ?? 999) prayers")
                    
                case .failure(let error):
                    print("❌ Failed to load stats: \(error)")
                }
            }
        }
    }
    
    /// Check if user can create more prayers based on their tier limit
    var canCreateMorePrayers: Bool {
        guard let stats = prayerStats else {
            return true // If we don't have stats yet, allow (will be validated by backend)
        }
        
        // If there's no limit (pro/lifetime), always allow
        guard let limit = stats.prayers.limit else {
            return true
        }
        
        // Check if under limit
        return stats.prayers.current < limit
    }
    
    /// Check if user has AI generation credits available
    var hasAICredits: Bool {
        return true
    }
    
    // MARK: - Playback (Delegates to AudioPlayerManager)
    
    /// Play a prayer with the user's selected voice
    func playPrayer(_ prayer: Prayer) {
        // Get current voice from VoiceService
        guard let voice = VoiceService.shared.getCurrentVoice() else {
            print("❌ No voice selected")
            errorMessage = "No voice selected"
            return
        }
        
        audioPlayer.playPrayer(prayer, voice: voice)
    }
    
    /// Stop any ongoing playback
    func stopSpeaking() {
        audioPlayer.stopSpeaking()
    }
    
    /// Check if currently speaking
    var isSpeaking: Bool {
        return audioPlayer.isSpeaking
    }
    
    // MARK: - Refresh All Data
    
    func refresh() {
        loadPrayers()
        loadStats()
        VoiceService.shared.fetchVoices()
    }
}
