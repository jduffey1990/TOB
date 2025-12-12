//
//  PrayerAPIService.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//

import Foundation

// MARK: - API Models

struct PrayerResponse: Codable {
    let id: String
    let userId: String
    let title: String
    let text: String
    let category: String?
    let isTemplate: Bool
    let playCount: Int
    let lastPlayedAt: String?
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case title
        case text
        case category
        case isTemplate
        case playCount
        case lastPlayedAt
        case createdAt
        case updatedAt
        case deletedAt
    }
}

struct PrayersListResponse: Codable {
    let prayers: [PrayerResponse]
    let count: Int
}

struct PrayerStatsResponse: Codable {
    let tier: String
    let isActive: Bool
    let expiresAt: String?
    let prayers: PrayerStats
    
    struct PrayerStats: Codable {
        let current: Int
        let limit: Int?
        let remaining: Int?
        let canCreate: Bool
    }
}

enum PrayerAPIError: Error {
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
            return "Prayer not found"
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

// MARK: - Prayer API Service

class PrayerAPIService {
    static let shared = PrayerAPIService()
    
    private let baseURL = Config.baseURL
    
    private init() {}
    
    // MARK: - Helper: Create Authorized Request
    
    private func createAuthorizedRequest(url: URL, method: String = "GET") -> URLRequest? {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ No auth token found")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    // MARK: - Fetch All Prayers
    
    func fetchPrayers(completion: @escaping (Result<[PrayerResponse], PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url) else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Fetching prayers from: \(url)")
        
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
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let listResponse = try JSONDecoder().decode(PrayersListResponse.self, from: data)
                    print("✅ Fetched \(listResponse.prayers.count) prayers")
                    completion(.success(listResponse.prayers))
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
    
    // MARK: - Create Prayer
    
    func createPrayer(title: String, text: String, category: String? = nil, completion: @escaping (Result<PrayerResponse, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url, method: "POST") else {
            completion(.failure(.unauthorized))
            return
        }
        
        let body: [String: Any] = [
            "title": title,
            "text": text,
            "category": category ?? NSNull()
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        print("🔵 Creating prayer: \(title)")
        
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
            
            switch httpResponse.statusCode {
            case 201:
                do {
                    let prayer = try JSONDecoder().decode(PrayerResponse.self, from: data)
                    print("✅ Prayer created: \(prayer.id)")
                    completion(.success(prayer))
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
                // Prayer limit reached
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.failure(.limitReached(message: message)))
                } else {
                    completion(.failure(.limitReached(message: "Prayer limit reached. Please upgrade to create more prayers.")))
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
    
    // MARK: - Update Prayer
    
    func updatePrayer(id: String, title: String?, text: String?, category: String?, completion: @escaping (Result<PrayerResponse, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers/\(id)") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url, method: "PATCH") else {
            completion(.failure(.unauthorized))
            return
        }
        
        var body: [String: Any] = [:]
        if let title = title { body["title"] = title }
        if let text = text { body["text"] = text }
        if let category = category { body["category"] = category }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        print("🔵 Updating prayer: \(id)")
        
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
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let prayer = try JSONDecoder().decode(PrayerResponse.self, from: data)
                    print("✅ Prayer updated: \(prayer.id)")
                    completion(.success(prayer))
                } catch {
                    print("❌ Decoding error: \(error)")
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
    
    // MARK: - Delete Prayer
    
    func deletePrayer(id: String, completion: @escaping (Result<Void, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers/\(id)") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url, method: "DELETE") else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Deleting prayer: \(id)")
        
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
            
            switch httpResponse.statusCode {
            case 200:
                print("✅ Prayer deleted")
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
    
    // MARK: - Record Playback
    
    func recordPlayback(id: String, completion: @escaping (Result<PrayerResponse, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers/\(id)/play") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url, method: "POST") else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Recording playback for prayer: \(id)")
        
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
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let prayer = try JSONDecoder().decode(PrayerResponse.self, from: data)
                    print("✅ Playback recorded for prayer: \(prayer.id)")
                    completion(.success(prayer))
                } catch {
                    print("❌ Decoding error: \(error)")
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
    
    // MARK: - Fetch Prayer Stats
    
    func fetchPrayerStats(completion: @escaping (Result<PrayerStatsResponse, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers/stats") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url) else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Fetching prayer stats")
        
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
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let stats = try JSONDecoder().decode(PrayerStatsResponse.self, from: data)
                    print("✅ Fetched prayer stats: \(stats.prayers.current)/\(stats.prayers.limit ?? 0) prayers")
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

// MARK: - Helper: Convert API Response to Local Prayer Model

extension PrayerResponse {
    func toLocalPrayer() -> Prayer {
        // Parse the ISO date string from the API
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        
        // Convert UUID string to UUID
        let uuid = UUID(uuidString: id) ?? UUID()
        
        return Prayer(
            id: uuid,
            title: title,
            text: text,
            createdAt: createdDate
        )
    }
}
