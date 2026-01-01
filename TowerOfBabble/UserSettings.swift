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
    var pitch: Float
    var volume: Float
    
    static let defaultSettings = UserSettings(
        voiceIndex: 0,
        pitch: 1.0,
        volume: 1.0
    )
}








