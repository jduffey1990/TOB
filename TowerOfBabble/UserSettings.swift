//
//  UserSettings.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/16/25.
//  User settings model matching backend UserSettings interface
//

import Foundation

struct UserSettings: Codable {
    var voiceIndex: Int
    var playbackRate: Float  // 0.0-1.0, where 0.5 = normal iOS speech rate
    
    // Computed properties for iOS AVSpeechSynthesizer compatibility
    var pitch: Float {
        // Convert playbackRate to pitch
        // playbackRate 0.5 (normal) -> pitch 1.0 (normal)
        // playbackRate 0.0 (slowest) -> pitch 0.5
        // playbackRate 1.0 (fastest) -> pitch 1.5
        return 0.5 + playbackRate
    }
    
    var rate: Float {
        // Convert playbackRate to AVSpeechUtterance rate
        // playbackRate 0.5 (normal) -> rate 0.5 (AVSpeechUtteranceDefaultSpeechRate)
        // This is a 1:1 mapping
        return playbackRate
    }
    
    var volume: Float {
        // Always return full volume for now
        return 1.0
    }
    
    static let defaultSettings = UserSettings(
        voiceIndex: 0,
        playbackRate: 0.5  // Normal speech rate
    )
        
        /// Fetch available voices from backen
}
