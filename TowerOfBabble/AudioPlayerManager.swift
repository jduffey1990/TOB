//
//  AudioPlayerManager.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 1/4/26.

//  Handles all audio playback, TTS, and audio state management
//  Integrates with new backend caching architecture (Redis + S3)
//

import Foundation
import AVFoundation
import Combine

// MARK: - Audio State Model

enum AudioState: Equatable {
    case missing
    case building
    case ready(url: URL)
    
    static func == (lhs: AudioState, rhs: AudioState) -> Bool {
        switch (lhs, rhs) {
        case (.missing, .missing), (.building, .building):
            return true
        case (.ready(let url1), .ready(let url2)):
            return url1 == url2
        default:
            return false
        }
    }
}

struct AudioStateResponse: Codable {
    let state: String  // "MISSING", "BUILDING", "READY"
    let audioUrl: String?
    let fileSize: Int?
    let duration: Double?
}

// MARK: - Audio Player Manager

class AudioPlayerManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    // MARK: - Published Properties
    
    @Published var isSpeaking: Bool = false
    @Published var isLoading: Bool = false
    @Published var audioState: AudioState = .missing
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let apiService = PrayerAPIService.shared
    private var pollingTimer: Timer?
    
    // Voice settings - injected from VoiceManager
    private var currentVoice: VoiceOption?
    private var volume: Float = 1.0
    private var pitch: Float = 1.0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    deinit {
        stopPolling()
    }
    
    // MARK: - Public API
    
    /// Set the current voice for playback
    func setVoice(_ voice: VoiceOption?) {
        self.currentVoice = voice
    }
    
    /// Set playback settings
    func setPlaybackSettings(volume: Float, pitch: Float) {
        self.volume = volume
        self.pitch = pitch
    }
    
    /// Main entry point: Play a prayer
    func playPrayer(_ prayer: Prayer, voice: VoiceOption) {
        // If already speaking, stop
        if isSpeaking {
            stopSpeaking()
            return
        }
        
        currentVoice = voice
        
        print("🎙️ Playing prayer with voice: \(voice.name) (\(voice.provider))")
        
        // Route based on provider
        switch voice.provider {
        case "apple":
            // Apple TTS - play immediately
            speakWithAppleTTS(prayer.text, voice: voice)
            recordPlayback(prayer)
            
        case "azure", "fishaudio":
            // Backend TTS - check state first
            playWithBackendTTS(prayer: prayer, voice: voice)
            
        default:
            print("⚠️ Unknown provider: \(voice.provider), falling back to Apple")
            speakWithAppleTTS(prayer.text, voice: voice)
            recordPlayback(prayer)
        }
    }
    
    /// Stop any ongoing playback
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        stopPolling()
    }
    
    /// Get button title based on current state
    var buttonTitle: String {
        if isSpeaking {
            return "Stop"
        }
        
        switch audioState {
        case .missing:
            return "Generate Audio"
        case .building:
            return "Building..."
        case .ready:
            return "Play"
        }
    }
    
    /// Is button disabled?
    var isButtonDisabled: Bool {
        return audioState == .building || isLoading
    }
    
    // MARK: - Backend TTS Flow (New Architecture)
    
    /// Play prayer using backend TTS with state checking
    private func playWithBackendTTS(prayer: Prayer, voice: VoiceOption) {
        isLoading = true
        
        // Step 1: Check current audio state
        checkAudioState(prayerId: prayer.id, voiceId: voice.id) { [weak self] state in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.audioState = state
                
                switch state {
                case .ready(let url):
                    // Audio exists - play it!
                    print("✅ Audio ready, playing from S3")
                    self.playRemoteAudio(url)
                    self.recordPlayback(prayer)
                    
                case .building:
                    // Audio is building - start polling
                    print("⏳ Audio building, starting poll")
                    self.startPolling(prayerId: prayer.id, voiceId: voice.id) { finalUrl in
                        self.playRemoteAudio(finalUrl)
                        self.recordPlayback(prayer)
                    }
                    
                case .missing:
                    // Audio doesn't exist - generate it
                    print("🚀 Audio missing, starting generation")
                    self.generateAudio(prayerId: prayer.id, voiceId: voice.id, prayer: prayer)
                }
            }
        }
    }
    
    // MARK: - Audio State Management
    
    /// Check audio state for a prayer + voice combination
    private func checkAudioState(
        prayerId: String,
        voiceId: String,
        completion: @escaping (AudioState) -> Void
    ) {
        guard let url = URL(string: "\(Config.baseURL)/prayers/\(prayerId)/audio-state?voiceId=\(voiceId)") else {
            completion(.missing)
            return
        }
        
        guard var request = apiService.createAuthorizedRequest(url: url, method: "GET") else {
            completion(.missing)
            return
        }
        
        print("🔍 Checking audio state for prayer: \(prayerId), voice: \(voiceId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ State check error: \(error)")
                completion(.missing)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                completion(.missing)
                return
            }
            
            do {
                let stateResponse = try JSONDecoder().decode(AudioStateResponse.self, from: data)
                print("📊 Audio state: \(stateResponse.state)")
                
                switch stateResponse.state {
                case "READY":
                    if let urlString = stateResponse.audioUrl,
                       let audioUrl = URL(string: urlString) {
                        completion(.ready(url: audioUrl))
                    } else {
                        completion(.missing)
                    }
                    
                case "BUILDING":
                    completion(.building)
                    
                default: // MISSING
                    completion(.missing)
                }
            } catch {
                print("❌ Failed to decode state: \(error)")
                completion(.missing)
            }
        }.resume()
    }
    
    /// Generate audio (starts async generation on backend)
    private func generateAudio(prayerId: String, voiceId: String, prayer: Prayer) {
        guard let url = URL(string: "\(Config.baseURL)/prayers/\(prayerId)/generate-audio") else {
            fallbackToAppleTTS(prayer.text)
            return
        }
        
        guard var request = apiService.createAuthorizedRequest(url: url, method: "POST") else {
            fallbackToAppleTTS(prayer.text)
            return
        }
        
        let body: [String: Any] = ["voiceId": voiceId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("🚀 Starting audio generation")
        isLoading = true
        audioState = .building
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Generation error: \(error)")
                    self.fallbackToAppleTTS(prayer.text)
                    self.recordPlayback(prayer)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.fallbackToAppleTTS(prayer.text)
                    self.recordPlayback(prayer)
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    // Already existed! Parse and play
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let urlString = json["audioUrl"] as? String,
                       let audioUrl = URL(string: urlString) {
                        print("✅ Audio already existed!")
                        self.audioState = .ready(url: audioUrl)
                        self.playRemoteAudio(audioUrl)
                        self.recordPlayback(prayer)
                    } else {
                        self.fallbackToAppleTTS(prayer.text)
                        self.recordPlayback(prayer)
                    }
                    
                case 202:
                    // Generation started - poll for completion
                    print("⏳ Generation started (202), polling...")
                    self.audioState = .building
                    self.startPolling(prayerId: prayerId, voiceId: voiceId) { finalUrl in
                        self.playRemoteAudio(finalUrl)
                        self.recordPlayback(prayer)
                    }
                    
                default:
                    print("❌ Generation failed: \(httpResponse.statusCode)")
                    self.fallbackToAppleTTS(prayer.text)
                    self.recordPlayback(prayer)
                }
            }
        }.resume()
    }
    
    // MARK: - Polling
    
    /// Poll audio state until READY
    private func startPolling(
        prayerId: String,
        voiceId: String,
        onReady: @escaping (URL) -> Void
    ) {
        stopPolling() // Clear any existing timer
        
        var pollCount = 0
        let maxPolls = 40 // 40 polls × 3 seconds = 2 minutes max
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            pollCount += 1
            print("🔄 Polling audio state (attempt \(pollCount)/\(maxPolls))")
            
            self.checkAudioState(prayerId: prayerId, voiceId: voiceId) { state in
                DispatchQueue.main.async {
                    self.audioState = state
                    
                    switch state {
                    case .ready(let url):
                        print("✅ Audio ready after \(pollCount) polls!")
                        timer.invalidate()
                        self.pollingTimer = nil
                        onReady(url)
                        
                    case .building:
                        print("   Still building...")
                        if pollCount >= maxPolls {
                            print("⚠️ Polling timeout after \(maxPolls) attempts")
                            timer.invalidate()
                            self.pollingTimer = nil
                            self.errorMessage = "Audio generation timed out"
                            self.audioState = .missing
                        }
                        
                    case .missing:
                        // Something went wrong
                        print("❌ Audio missing during poll (generation failed?)")
                        timer.invalidate()
                        self.pollingTimer = nil
                        self.errorMessage = "Audio generation failed"
                        self.audioState = .missing
                    }
                }
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Audio Playback
    
    /// Play audio from remote URL (S3)
    private func playRemoteAudio(_ url: URL) {
        print("🔊 Playing audio from: \(url)")
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Download error: \(error)")
                    self.errorMessage = "Failed to download audio"
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    self.errorMessage = "No audio data"
                    return
                }
                
                self.playAudioData(data)
            }
        }.resume()
    }
    
    /// Play audio data using AVAudioPlayer
    private func playAudioData(_ data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = volume
            
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
    
    // MARK: - Apple TTS (Fallback)
    
    /// Use Apple's built-in TTS
    private func speakWithAppleTTS(_ text: String, voice: VoiceOption? = nil) {
        let utterance = AVSpeechUtterance(string: text)
        
        if let voice = voice ?? currentVoice,
           voice.provider == "apple" {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voice.id)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        
        synthesizer.speak(utterance)
    }
    
    private func fallbackToAppleTTS(_ text: String) {
        print("⚠️ Falling back to Apple TTS")
        speakWithAppleTTS(text)
    }
    
    // MARK: - Record Playback
    
    private func recordPlayback(_ prayer: Prayer) {
        apiService.recordPlayback(id: prayer.id) { result in
            switch result {
            case .success:
                print("✅ Playback recorded")
            case .failure(let error):
                print("⚠️ Failed to record playback: \(error)")
            }
        }
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
}

// MARK: - Extension for PrayerAPIService (Helper)

extension PrayerAPIService {
    func createAuthorizedRequest(url: URL, method: String) -> URLRequest? {
        guard let token = AuthManager.shared.getToken() else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }
}
