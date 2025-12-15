//
//  PrayOnItItem.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/15/25.
//  Pray On It Item Model
//

import Foundation

struct PrayOnItItem: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var name: String
    var category: Category
    var relationship: String?
    var prayerFocus: String?
    var notes: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum Category: String, Codable, CaseIterable {
        case family = "family"
        case friends = "friends"
        case work = "work"
        case health = "health"
        case personal = "personal"
        case world = "world"
        case other = "other"
        
        var displayName: String {
            return rawValue.capitalized
        }
    }
}
