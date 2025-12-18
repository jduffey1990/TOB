//
//  PrayOnItManager.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/15/25.
//  Updateed by Jordan Duffey on 12/17/25.
//  Converted to singleton pattern for shared state across views
//

import Foundation
import Combine

// Model for a single pray-on-it item (local representation)
struct PrayOnItItem: Identifiable, Codable {
    let id: String
    let userId: String
    var name: String
    var category: Category
    var relationship: String?
    var prayerFocus: PrayerFocus?
    var notes: String?
    let createdAt: String
    let updatedAt: String
    
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
    
    enum PrayerFocus: String, Codable, CaseIterable {
        case healing = "healing"
        case guidance = "guidance"
        case thanksgiving = "thanksgiving"
        case protection = "protection"
        case peace = "peace"
        case strength = "strength"
        case wisdom = "wisdom"
        case comfort = "comfort"
        case provision = "provision"
        case salvation = "salvation"
        case restoration = "restoration"
        case patience = "patience"
        
        var displayName: String {
            return rawValue.capitalized
        }
    }
}

class PrayOnItManager: ObservableObject {
    // MARK: - Singleton
    static let shared = PrayOnItManager()
    
    // MARK: - Published Properties
    @Published var items: [PrayOnItItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var stats: PrayOnItStatsResponse?
    
    // MARK: - Private Properties
    private let apiService = PrayOnItAPIService.shared
    
    // Local cache key for offline support
    private let itemsKey = "cachedPrayOnItItems"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    private init() {
        loadItemsFromCache()
        fetchItemsFromAPI()
        fetchStats()
    }
    
    // MARK: - Stats Helpers
    
    var itemCountText: String {
        guard let stats = stats else {
            return "\(items.count) items"
        }
        
        if let limit = stats.items.limit {
            return "\(stats.items.current)/\(limit) items"
        } else {
            return "\(stats.items.current) items (unlimited)"
        }
    }
    
    var canCreateMoreItems: Bool {
        guard let stats = stats else {
            return true // Assume yes if we don't have stats yet
        }
        return stats.items.canCreate
    }
    
    var tierDisplayText: String {
        guard let stats = stats else {
            return "Loading..."
        }
        
        if let limit = stats.items.limit {
            return "\(stats.tier.capitalized) tier: \(limit) items max"
        } else {
            return "\(stats.tier.capitalized) tier: Unlimited items"
        }
    }
    
    var currentCount: Int {
        return stats?.items.current ?? items.count
    }
    
    var limit: Int? {
        return stats?.items.limit
    }
    
    // MARK: - Fetch Stats
    
    func fetchStats() {
        apiService.fetchStats { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let statsResponse):
                    self?.stats = statsResponse
                    print("✅ Stats: \(statsResponse.items.current)/\(statsResponse.items.limit ?? 0) items")
                    
                case .failure(let error):
                    print("⚠️ Failed to fetch stats: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Fetch Items from API
    
    func fetchItemsFromAPI() {
        isLoading = true
        errorMessage = nil
        
        apiService.fetchItems { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let items):
                    self?.items = items
                    self?.saveItemsToCache()
                    print("✅ Loaded \(items.count) pray-on-it items from API")
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to fetch items: \(error.localizedDescription)")
                    
                    // If network fails, we still have cached items loaded
                    if self?.items.isEmpty == true {
                        self?.loadItemsFromCache()
                    }
                }
            }
        }
    }
    
    // MARK: - Create Item
    
    func addItem(
        name: String,
        category: PrayOnItItem.Category,
        relationship: String?,
        prayerFocus: PrayOnItItem.PrayerFocus?,
        notes: String?,
        completion: ((Result<PrayOnItItem, PrayOnItAPIError>) -> Void)? = nil
    ) {
        isLoading = true
        errorMessage = nil
        
        apiService.createItem(
            name: name,
            category: category.rawValue,
            relationship: relationship,
            prayerFocus: prayerFocus?.rawValue,
            notes: notes
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let items):
                    let newItem = items
                    self?.items.append(newItem)
                    self?.saveItemsToCache()
                    self?.fetchStats() // Immediately refresh stats
                    print("✅ Pray-on-it item created")
                    completion?(.success(newItem))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to create item: \(error.localizedDescription)")
                    
                    // Special handling for limit reached
                    if case .limitReached = error {
                        self?.fetchStats() // Refresh stats to show accurate limits
                    }
                    
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Update Item
    
    func updateItem(
        _ item: PrayOnItItem,
        name: String?,
        category: PrayOnItItem.Category?,
        relationship: String?,
        prayerFocus: PrayOnItItem.PrayerFocus?,
        notes: String?,
        completion: ((Result<PrayOnItItem, PrayOnItAPIError>) -> Void)? = nil
    ) {
        isLoading = true
        errorMessage = nil
        
        apiService.updateItem(
            id: item.id,
            name: name,
            category: category?.rawValue,
            relationship: relationship,
            prayerFocus: prayerFocus?.rawValue,
            notes: notes
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let item):
                    let updatedItem = item
                    if let index = self?.items.firstIndex(where: { $0.id == item.id }) {
                        self?.items[index] = updatedItem
                        self?.saveItemsToCache()
                        print("✅ Pray-on-it item updated")
                    }
                    completion?(.success(updatedItem))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to update item: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Delete Item
    
    func deleteItem(_ item: PrayOnItItem, completion: ((Result<Void, PrayOnItAPIError>) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.deleteItem(id: item.id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.items.removeAll { $0.id == item.id }
                    self?.saveItemsToCache()
                    self?.fetchStats() // Immediately refresh stats
                    print("✅ Pray-on-it item deleted")
                    completion?(.success(()))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    print("❌ Failed to delete item: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Local Cache (for offline support)
    
    private func saveItemsToCache() {
        if let encoded = try? JSONEncoder().encode(items) {
            defaults.set(encoded, forKey: itemsKey)
            print("💾 Cached \(items.count) pray-on-it items locally")
        }
    }
    
    private func loadItemsFromCache() {
        if let data = defaults.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([PrayOnItItem].self, from: data) {
            items = decoded
            print("💾 Loaded \(items.count) pray-on-it items from cache")
        }
    }
    
    // MARK: - Manual Refresh
    
    func refresh() {
        fetchItemsFromAPI()
        fetchStats()
    }
    
    // MARK: - Helper: Get items by category
    
    func items(for category: PrayOnItItem.Category) -> [PrayOnItItem] {
        return items.filter { $0.category == category }
    }
}
