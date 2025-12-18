//
//  UserSettings.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/16/25.
//  User settings model matching backend UserSettings interface
//

import Foundation

struct UserSettings: Codable {
    var voiceIndex: Int         // 0-8 depending on tier
    var playbackRate: Double    // 0.0-1.0, where 0.5 = normal
    
    // Default settings
    static let defaultSettings = UserSettings(
        voiceIndex: 0,
        playbackRate: 0.5
    )
}








