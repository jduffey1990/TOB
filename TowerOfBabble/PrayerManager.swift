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
    @Published var availableVoices: [VoiceOption] = []
    @Published var allVoices: [VoiceOption] = []
    @Published var userTier: String = "free"
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
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
        fetchAvailableVoices()
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
            print("💾 Loaded saved settings: voice=\(decoded.voiceIndex)")
        } else {
            print("💾 No saved settings found, using defaults")
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: "userSettings")
        }
    }
    
    /// Fetch available voices from backend
    func fetchAvailableVoices(completion: ((Result<VoicesResponse, PrayerAPIError>) -> Void)? = nil) {
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
                    completion?(.failure(error))
                }
            }
        }
    }

    /// Get available voices for UI picker (returns display names)
    func getAvailableVoices() -> [String] {
        return availableVoices.map { voice in
            "\(voice.name) (\(voice.provider.capitalized))"
        }
    }
    
    /// Get a specific voice by index
    func getVoiceByIndex(_ index: Int) -> VoiceOption? {
        guard index >= 0 && index < availableVoices.count else {
            return nil
        }
        return availableVoices[index]
    }

    
    /// Check if a voice is locked (requires upgrade)
    func isVoiceLocked(_ voice: VoiceOption) -> Bool {
        return !availableVoices.contains(where: { $0.id == voice.id })
    }
    
    
    /// Get Apple-specific voices for local TTS
    private func getAppleVoices() -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Allowlist of known high-quality voices
        let allowedVoiceNames = [
            "Samantha",    // Natural female (Enhanced)
            "Moira",       // Irish female (Enhanced)
            "Daniel",      // British male (Enhanced)
        ]
        
        let voices = allVoices.filter { voice in
            guard voice.language.hasPrefix("en-") else { return false }
            return allowedVoiceNames.contains(voice.name)
        }
        
        let sortedVoices = voices.sorted { voice1, voice2 in
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
        
        if sortedVoices.isEmpty {
            print("⚠️ No allowlisted voices found, falling back to enhanced voices")
            return allVoices.filter { voice in
                voice.language.hasPrefix("en-") && voice.quality == .enhanced
            }.sorted { $0.name < $1.name }
        }
        
        return sortedVoices
    }
        
    
    // MARK: - Prayer Stats
    
    var hasAICredits: Bool {
        return true
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
    
    
    // MARK: - Text-to-Speech (UPDATED)

    /// Play a saved prayer (routes to appropriate TTS provider)
    func speakPrayer(_ prayer: Prayer) {
        if isSpeaking {
            stopSpeaking()
            return
        }
        
        // Get selected voice
        guard let voice = getVoiceByIndex(settings.voiceIndex) else {
            print("⚠️ No voice selected, using default Apple voice")
            speakWithAppleTTS(prayer.text)
            recordPlayback(prayer)
            return
        }
        
        print("🎙️ Speaking prayer with voice: \(voice.name) (\(voice.provider))")
        
        // Route to appropriate provider
        switch voice.provider {
        case "apple":
            speakWithAppleTTS(prayer.text)
            recordPlayback(prayer)
            
        case "azure", "fishaudio":
            speakWithBackendTTS(prayer: prayer, voice: voice)
            
        default:
            print("⚠️ Unknown provider: \(voice.provider), falling back to Apple")
            speakWithAppleTTS(prayer.text)
            recordPlayback(prayer)
        }
    }

    /// Preview text without recording playback
    func speakText(_ text: String) {
        if isSpeaking {
            stopSpeaking()
            return
        }
        
        guard let voice = getVoiceByIndex(settings.voiceIndex) else {
            speakWithAppleTTS(text)
            return
        }
        
        print("🎙️ Previewing with voice: \(voice.name) (\(voice.provider))")
        
        switch voice.provider {
        case "apple":
            speakWithAppleTTS(text)
            
        case "azure", "fishaudio":
            // For preview, we'd need to create a temporary prayer or handle differently
            // For now, just use Apple TTS for previews
            print("⚠️ Backend TTS preview not implemented, using Apple")
            speakWithAppleTTS(text)
            
        default:
            speakWithAppleTTS(text)
        }
    }

    /// Stop any ongoing speech
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }
    
    // MARK: - Private TTS Methods

    /// Use Apple's built-in TTS (client-side)
    private func speakWithAppleTTS(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        
        // Try to find the Apple voice by ID
        if let voice = getVoiceByIndex(settings.voiceIndex),
           voice.provider == "apple" {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voice.id)
        } else {
            // Fallback to default
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.pitchMultiplier = settings.pitch
        utterance.volume = settings.volume
        
        synthesizer.speak(utterance)
    }

    /// Use backend TTS (Azure or Fish Audio)
    private func speakWithBackendTTS(prayer: Prayer, voice: VoiceOption) {
        isLoading = true
        
        apiService.generateAudio(prayerId: prayer.id, voiceId: voice.id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let audioResponse):
                    print("✅ Received audio from backend")
                    print("   Provider: \(audioResponse.provider)")
                    print("   Voice: \(audioResponse.voiceUsed)")
                    
                    // Decode base64 audio data
                    guard let audioData = Data(base64Encoded: audioResponse.audioData) else {
                        print("❌ Failed to decode base64 audio")
                        self?.errorMessage = "Failed to decode audio"
                        return
                    }
                    
                    // Play the audio
                    self?.playAudioData(audioData)
                    
                    // Record playback
                    self?.recordPlayback(prayer)
                    
                case .failure(let error):
                    print("❌ Failed to generate audio: \(error)")
                    self?.errorMessage = error.localizedDescription
                    
                    // Fallback to Apple TTS
                    print("⚠️ Falling back to Apple TTS")
                    self?.speakWithAppleTTS(prayer.text)
                    self?.recordPlayback(prayer)
                }
            }
        }
    }

    /// Play audio data using AVAudioPlayer
    private func playAudioData(_ data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = settings.volume
            
            // Set up audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer?.play()
            isSpeaking = true
            
            // Monitor playback completion
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self,
                      let player = self.audioPlayer else {
                    timer.invalidate()
                    return
                }
                
                if !player.isPlaying {
                    timer.invalidate()
                    self.isSpeaking = false
                    self.audioPlayer = nil
                }
            }
            
        } catch {
            print("❌ Failed to play audio: \(error)")
            errorMessage = "Failed to play audio"
            isSpeaking = false
        }
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






