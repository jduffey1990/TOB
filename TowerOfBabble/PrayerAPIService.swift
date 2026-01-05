//
//  PrayerAPIService.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//  Updated by Claude on 12/17/25 - Added AuthManager integration
//

import Foundation

// MARK: - API Models
struct PrayersListResponse: Codable {
    let prayers: [Prayer]
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

struct GenerateAudioRequest: Codable {
    let voiceId: String
}

struct GenerateAudioResponse: Codable {
    let success: Bool
    let audioData: String  // Base64 encoded
    let audioFormat: String
    let voiceUsed: String
    let provider: String
    let metadata: AudioMetadata
    
    struct AudioMetadata: Codable {
        let characterCount: Int
        let estimatedCost: Double
        let generatedAt: String
        let responseTimeMs: Int
    }
}

// MARK: - Prayer API Service

class PrayerAPIService {
    static let shared = PrayerAPIService()
    
    private let baseURL = Config.baseURL
    
    private init() {}
    
    // MARK: - Helper: Handle HTTP Response with 401 Detection
    
    private func handle401IfNeeded(_ statusCode: Int) {
        if statusCode == 401 {
            print("⚠️ 401 Unauthorized - token expired")
            DispatchQueue.main.async {
                AuthManager.shared.handleTokenExpired()
            }
        }
    }
    
    // MARK: - Fetch All Prayers
    
    func fetchPrayers(completion: @escaping (Result<[Prayer], PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = APIClient.shared.createAuthorizedRequest(url: url) else {
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
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    // Add this to see the raw JSON
                   if let jsonString = String(data: data, encoding: .utf8) {
                       print("📦 Raw JSON response from /prayers:")
                       print(jsonString.prefix(500)) // First 500 chars
                   }
                    let listResponse = try JSONDecoder().decode(PrayersListResponse.self, from: data)
                    print("✅ Fetched \(listResponse.prayers.count) prayers")
                    
                    // Add this to see what IDs we got
                    for prayer in listResponse.prayers {
                        print("   Prayer: id=\(prayer.id), title=\(prayer.title)")
                    }
                    
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
    
    func createPrayer(title: String, text: String, category: String? = nil, completion: @escaping (Result<Prayer, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = APIClient.shared.createAuthorizedRequest(url: url, method: "POST") else {
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
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 201:
                do {
                    let prayer = try JSONDecoder().decode(Prayer.self, from: data)
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
    
    
    func createPrompt(
        _ requestPayload: [String: Any],
        completion: @escaping (Result<String, PrayerAPIError>) -> Void
    ) {
        print("\n🔵 [PrayerAPIService] createPrompt called")
        
        // Log full payload in JSON format
        if let jsonData = try? JSONSerialization.data(withJSONObject: requestPayload, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📦 Full Request Payload:")
            print(jsonString)
        }
        
        // Extract payload details for logging
        let prayerType = requestPayload["prayerType"] as? String ?? "unknown"
        let tone = requestPayload["tone"] as? String ?? "unknown"
        let length = requestPayload["length"] as? String ?? "unknown"
        let expansiveness = requestPayload["expansiveness"] as? String ?? "unknown"
        
        var itemNames: [String] = []
        if let items = requestPayload["prayOnItItems"] as? [[String: Any]] {
            itemNames = items.compactMap { $0["name"] as? String }
        }
        
        print("\n📊 Request Summary:")
        print("   Prayer Type: \(prayerType)")
        print("   Tone: \(tone)")
        print("   Length: \(length)")
        print("   Expansiveness: \(expansiveness)")
        print("   Praying for: \(itemNames.joined(separator: ", "))")
        
        // Check if we have custom context
        if let context = requestPayload["customContext"], !(context is NSNull) {
            print("   Custom Context: \(context)")
        } else {
            print("   Custom Context: None")
        }
        
        // ACTUAL API IMPLEMENTATION
        guard let url = URL(string: "\(baseURL)/prayers/ai-gen") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = APIClient.shared.createAuthorizedRequest(url: url, method: "POST") else {
            completion(.failure(.unauthorized))
            return
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestPayload)
        } catch {
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        print("🚀 [PrayerAPIService] Sending POST to /prayers/ai-gen")
        
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
                    // Log the raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📦 Raw JSON response from /prayers/ai-gen:")
                        print(jsonString.prefix(500))
                    }
                    
                    // Parse the response
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let generatedText = json["generatedText"] as? String {
                        
                        // Optional: extract additional info
                        let generatedTitle = json["generatedTitle"] as? String
                        let creditsRemaining = json["creditsRemaining"] as? Int
                        let creditsLimit = json["creditsLimit"] as? Int
                        
                        print("✅ AI prayer generated (\(generatedText.count) chars)")
                        if let title = generatedTitle {
                            print("   Title: \(title)")
                        }
                        if let remaining = creditsRemaining, let limit = creditsLimit {
                            print("   Credits: \(remaining)/\(limit) remaining")
                        }
                        
                        completion(.success(generatedText))
                    } else {
                        print("❌ Invalid response format - missing generatedText")
                        completion(.failure(.decodingError))
                    }
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
                // AI generation limit reached
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.failure(.limitReached(message: message)))
                } else {
                    completion(.failure(.limitReached(message: "AI generation limit reached. Please upgrade.")))
                }
                
            case 503:
                // AI service error
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.failure(.serverError("AI service unavailable: \(message)")))
                } else {
                    completion(.failure(.serverError("AI service temporarily unavailable")))
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
    
    func updatePrayer(id: String, title: String?, text: String?, category: String?, completion: @escaping (Result<Prayer, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers/\(id)") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = APIClient.shared.createAuthorizedRequest(url: url, method: "PATCH") else {
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
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let prayer = try JSONDecoder().decode(Prayer.self, from: data)
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
        
        guard let request = APIClient.shared.createAuthorizedRequest(url: url, method: "DELETE") else {
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
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
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
    
    
    // MARK: - Fetch Available Voices

    func fetchVoices(completion: @escaping (Result<VoicesResponse, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/voices") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = APIClient.shared.createAuthorizedRequest(url: url) else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Fetching available voices")
        
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
            
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📦 Raw voices response:")
                        print(jsonString.prefix(500))
                    }
                    
                    let voicesResponse = try JSONDecoder().decode(VoicesResponse.self, from: data)
                    print("✅ Fetched \(voicesResponse.availableVoices.count) available voices")
                    print("   User tier: \(voicesResponse.userTier)")
                    completion(.success(voicesResponse))
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

    // MARK: - Generate Audio for Prayer

    func generateAudio(prayerId: String, voiceId: String, completion: @escaping (Result<GenerateAudioResponse, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers/\(prayerId)/generate-audio") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = APIClient.shared.createAuthorizedRequest(url: url, method: "POST") else {
            completion(.failure(.unauthorized))
            return
        }
        
        let body: [String: Any] = ["voiceId": voiceId]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        print("🔵 Generating audio for prayer: \(prayerId)")
        print("   Voice: \(voiceId)")
        
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
            
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let audioResponse = try JSONDecoder().decode(GenerateAudioResponse.self, from: data)
                    print("✅ Audio generated successfully")
                    print("   Provider: \(audioResponse.provider)")
                    print("   Voice: \(audioResponse.voiceUsed)")
                    print("   Size: \(audioResponse.audioData.count) bytes (base64)")
                    completion(.success(audioResponse))
                } catch {
                    print("❌ Decoding error: \(error)")
                    completion(.failure(.decodingError))
                }
                
            case 401:
                completion(.failure(.unauthorized))
                
            case 403:
                // Voice tier not available
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.failure(.serverError("Upgrade required: \(message)")))
                } else {
                    completion(.failure(.serverError("This voice requires a higher subscription tier")))
                }
                
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
    
    // MARK: - Record Playback
    func recordPlayback(id: String, completion: @escaping (Result<Prayer, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers/\(id)/play") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = APIClient.shared.createAuthorizedRequest(url: url, method: "POST") else {
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
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let prayer = try JSONDecoder().decode(Prayer.self, from: data)
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
        
        guard let request = APIClient.shared.createAuthorizedRequest(url: url) else {
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
            
            // ✅ Handle 401 globally
            self.handle401IfNeeded(httpResponse.statusCode)
            
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
