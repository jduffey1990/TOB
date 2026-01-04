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

class PrayerManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PrayerManager()
    
    // MARK: - Published Properties
    
    @Published var prayers: [Prayer] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var prayerStats: PrayerStatsResponse?
    
    // MARK: - Private Properties
    
    private let apiService = PrayerAPIService.shared
    private let prayersKey = "cachedPrayers"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    private init() {
        loadPrayersFromCache()
        fetchPrayersFromAPI()
        fetchStats()
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
                    self?.prayers = prayers
                    self?.savePrayersToCache()
                    print("✅ Loaded \(prayers.count) prayers from API")
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to fetch prayers: \(error.localizedDescription)")
                    
                    // Keep cached prayers if API fails
                    if self?.prayers.isEmpty == true {
                        self?.loadPrayersFromCache()
                    }
                }
            }
        }
    }
    
    // MARK: - Create Prayer
    
    func addPrayer(
        title: String,
        text: String,
        completion: ((Result<Prayer, PrayerAPIError>) -> Void)? = nil
    ) {
        isLoading = true
        errorMessage = nil
        
        apiService.createPrayer(title: title, text: text) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let newPrayer):
                    self?.prayers.append(newPrayer)
                    self?.savePrayersToCache()
                    self?.fetchStats() // Update stats after creating
                    print("✅ Prayer created: \(newPrayer.id)")
                    completion?(.success(newPrayer))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to create prayer: \(error.localizedDescription)")
                    
                    // Refresh stats if limit reached
                    if case .limitReached = error {
                        self?.fetchStats()
                    }
                    
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - AI Prayer Generation
    
    func generatePrayerWithAI(
        _ requestPayload: [String: Any],
        completion: ((Result<String, PrayerAPIError>) -> Void)? = nil
    ) {
        print("\n🟦 [PrayerManager] Generating AI prayer")
        print("   Payload keys: \(requestPayload.keys.joined(separator: ", "))")
        
        isLoading = true
        errorMessage = nil
        
        apiService.createPrompt(requestPayload) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let generatedText):
                    print("✅ [PrayerManager] AI prayer generated (\(generatedText.count) chars)")
                    completion?(.success(generatedText))
                    
                case .failure(let error):
                    print("❌ [PrayerManager] AI generation failed: \(error)")
                    self?.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Update Prayer
    
    func updatePrayer(
        _ prayer: Prayer,
        completion: ((Result<Prayer, PrayerAPIError>) -> Void)? = nil
    ) {
        isLoading = true
        errorMessage = nil
        
        apiService.updatePrayer(
            id: prayer.id,
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
                        print("✅ Prayer updated: \(updatedPrayer.id)")
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
    
    func deletePrayer(
        _ prayer: Prayer,
        completion: ((Result<Void, PrayerAPIError>) -> Void)? = nil
    ) {
        isLoading = true
        errorMessage = nil
        
        apiService.deletePrayer(id: prayer.id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.prayers.removeAll { $0.id == prayer.id }
                    self?.savePrayersToCache()
                    self?.fetchStats() // Update stats after deleting
                    print("✅ Prayer deleted: \(prayer.id)")
                    completion?(.success(()))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to delete prayer: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Prayer Stats
    
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
            return true // Assume yes if stats not loaded
        }
        return stats.prayers.canCreate
    }
    
    var hasAICredits: Bool {
        // TODO: Add AI credits tracking if needed
        return true
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











