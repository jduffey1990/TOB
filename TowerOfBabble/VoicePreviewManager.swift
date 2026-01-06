//
//  VoicePreviewManager.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 1/5/26.
//

import AVFoundation
import SwiftUI
import Combine 

class VoicePreviewManager: NSObject, ObservableObject {
    static let shared = VoicePreviewManager()
    
    @Published var isPlaying: Bool = false
    @Published var currentPlayingVoiceId: String? = nil
    
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let previewText = "Have your prayers read in my voice."
    
    private override init() {
        super.init()
    }
    
    /// Preview a voice (bundled audio or Apple TTS)
    func previewVoice(_ voice: VoiceOption) {
        // Stop any current playback
        stop()
        
        if voice.provider == "apple" {
            previewAppleVoice(voice)
        } else if let filename = voice.file {
            previewBundledAudio(filename: filename)
        } else {
            print("⚠️ No preview available for voice: \(voice.name)")
            return
        }
        
        currentPlayingVoiceId = voice.id
        isPlaying = true
    }
    
    /// Stop current playback
    func stop() {
        audioPlayer?.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentPlayingVoiceId = nil
    }
    
    // MARK: - Private Methods
    
    private func previewAppleVoice(_ voice: VoiceOption) {
        let utterance = AVSpeechUtterance(string: previewText)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voice.id)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
        
        // Auto-stop when done (estimated duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.speechSynthesizer.isSpeaking == false {
                self?.stop()
            }
        }
    }
    
    private func previewBundledAudio(filename: String) {

        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3") else {
            print("⚠️ Preview file not found: \(filename).mp3")
            stop()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            print("▶️ Playing preview: \(filename).mp3")
        } catch {
            print("❌ Failed to play preview: \(error)")
            stop()
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoicePreviewManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.stop()
        }
    }
}

