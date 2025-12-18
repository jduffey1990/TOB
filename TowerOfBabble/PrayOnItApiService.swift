//
//  PrayOnItAPIService.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/15/25
//  Updated by Claude on 12/17/25 - Added AuthManager integration
//

import Foundation

// MARK: - API Models

struct PrayOnItItemsListResponse: Codable {
    let items: [PrayOnItItem]
    let count: Int
}

struct PrayOnItStatsResponse: Codable {
    let tier: String
    let items: ItemStats
    
    struct ItemStats: Codable {
        let current: Int
        let limit: Int?
        let remaining: Int?
        let canCreate: Bool
    }
}

enum PrayOnItAPIError: Error {
    case unauthorized
    case limitReached(message: String)
    case notFound
    case networkError(String)
    case serverError(String)
    case decodingError
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .unauthorized:
            return "Please log in again"
        case .limitReached(let message):
            return message
        case .notFound:
            return "Pray On It item not found"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError:
            return "Failed to process server response"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Pray On It API Service

class PrayOnItAPIService {
    static let shared = PrayOnItAPIService()
    
    private let baseURL = Config.baseURL
    
    private init() {}
    
    // MARK: - Helper: Create Authorized Request
    
    private func createAuthorizedRequest(url: URL, method: String = "GET") -> URLRequest? {
        // ✅ Get token from AuthManager instead of UserDefaults
        guard let token = AuthManager.shared.getToken() else {
            print("❌ No auth token found")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    // MARK: - Helper: Handle HTTP Response with 401 Detection
    
    private func handle401IfNeeded(_ statusCode: Int) {
        if statusCode == 401 {
            print("⚠️ 401 Unauthorized - token expired")
            DispatchQueue.main.async {
                AuthManager.shared.handleTokenExpired()
            }
        }
    }
    
    // MARK: - Fetch All Items
    
    func fetchItems(completion: @escaping (Result<[PrayOnItItem], PrayOnItAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/pray-on-it") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = createAuthorizedRequest(url: url) else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Fetching pray-on-it items from: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }
            
            guard let data = data else {
                completion(.failure(.networkError("No data received")))
                return
            }
            
            print("🔵 Response status: \(httpResponse.statusCode)")
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let listResponse = try JSONDecoder().decode(PrayOnItItemsListResponse.self, from: data)
                    print("✅ Fetched \(listResponse.items.count) pray-on-it items")
                    completion(.success(listResponse.items))
                } catch {
                    print("❌ Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response: \(jsonString)")
                    }
                    completion(.failure(.decodingError))
                }
                
            case 401:
                completion(.failure(.unauthorized))
                
            default:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.serverError("Server error: \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }
    
    // MARK: - Create Item
    
    func createItem(name: String, category: String, relationship: String? = nil, prayerFocus: String? = nil, notes: String? = nil, completion: @escaping (Result<PrayOnItItem, PrayOnItAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/pray-on-it") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url, method: "POST") else {
            completion(.failure(.unauthorized))
            return
        }
        
        var body: [String: Any] = [
            "name": name,
            "category": category
        ]
        
        if let relationship = relationship, !relationship.isEmpty {
            body["relationship"] = relationship
        }
        if let prayerFocus = prayerFocus, !prayerFocus.isEmpty {
            body["prayerFocus"] = prayerFocus
        }
        if let notes = notes, !notes.isEmpty {
            body["notes"] = notes
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        print("🔵 Creating pray-on-it item: \(name)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }
            
            guard let data = data else {
                completion(.failure(.networkError("No data received")))
                return
            }
            
            print("🔵 Response status: \(httpResponse.statusCode)")
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 201:
                do {
                    let item = try JSONDecoder().decode(PrayOnItItem.self, from: data)
                    print("✅ Pray-on-it item created: \(item.id)")
                    completion(.success(item))
                } catch {
                    print("❌ Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response: \(jsonString)")
                    }
                    completion(.failure(.decodingError))
                }
                
            case 401:
                completion(.failure(.unauthorized))
                
            case 402:
                // Item limit reached
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.failure(.limitReached(message: message)))
                } else {
                    completion(.failure(.limitReached(message: "Pray On It item limit reached. Please upgrade to create more items.")))
                }
                
            default:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.serverError("Server error: \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }
    
    // MARK: - Update Item
    
    func updateItem(id: String, name: String? = nil, category: String? = nil, relationship: String? = nil, prayerFocus: String? = nil, notes: String? = nil, completion: @escaping (Result<PrayOnItItem, PrayOnItAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/pray-on-it/\(id)") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url, method: "PATCH") else {
            completion(.failure(.unauthorized))
            return
        }
        
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let category = category { body["category"] = category }
        if let relationship = relationship {
            body["relationship"] = relationship.isEmpty ? NSNull() : relationship
        }
        if let prayerFocus = prayerFocus {
            body["prayerFocus"] = prayerFocus.isEmpty ? NSNull() : prayerFocus
        }
        if let notes = notes {
            body["notes"] = notes.isEmpty ? NSNull() : notes
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        print("🔵 Updating pray-on-it item: \(id)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }
            
            guard let data = data else {
                completion(.failure(.networkError("No data received")))
                return
            }
            
            print("🔵 Response status: \(httpResponse.statusCode)")
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let item = try JSONDecoder().decode(PrayOnItItem.self, from: data)
                    print("✅ Pray-on-it item updated: \(item.id)")
                    completion(.success(item))
                } catch {
                    print("❌ Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response: \(jsonString)")
                    }
                    completion(.failure(.decodingError))
                }
                
            case 401:
                completion(.failure(.unauthorized))
                
            case 404:
                completion(.failure(.notFound))
                
            default:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.serverError("Server error: \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }
    
    // MARK: - Delete Item
    
    func deleteItem(id: String, completion: @escaping (Result<Void, PrayOnItAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/pray-on-it/\(id)") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = createAuthorizedRequest(url: url, method: "DELETE") else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Deleting pray-on-it item: \(id)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }
            
            print("🔵 Response status: \(httpResponse.statusCode)")
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                print("✅ Pray-on-it item deleted")
                completion(.success(()))
                
            case 401:
                completion(.failure(.unauthorized))
                
            case 404:
                completion(.failure(.notFound))
                
            default:
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.serverError("Server error: \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch Stats
    
    func fetchStats(completion: @escaping (Result<PrayOnItStatsResponse, PrayOnItAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/pray-on-it/stats") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = createAuthorizedRequest(url: url) else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Fetching pray-on-it stats")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown))
                return
            }
            
            guard let data = data else {
                completion(.failure(.networkError("No data received")))
                return
            }
            
            print("🔵 Response status: \(httpResponse.statusCode)")
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let stats = try JSONDecoder().decode(PrayOnItStatsResponse.self, from: data)
                    print("✅ Fetched pray-on-it stats: \(stats.items.current)/\(stats.items.limit ?? 0) items")
                    completion(.success(stats))
                } catch {
                    print("❌ Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response: \(jsonString)")
                    }
                    completion(.failure(.decodingError))
                }
                
            case 401:
                completion(.failure(.unauthorized))
                
            default:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.serverError("Server error: \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }
}
