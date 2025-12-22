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

// MARK: - Prayer API Service

class PrayerAPIService {
    static let shared = PrayerAPIService()
    
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
    
    // MARK: - Fetch All Prayers
    
    func fetchPrayers(completion: @escaping (Result<[Prayer], PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = createAuthorizedRequest(url: url) else {
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
        
        guard var request = createAuthorizedRequest(url: url, method: "POST") else {
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
    
    private func generateMockPrayer(
        items: [String],
        type: String,
        tone: String,
        length: String,
        expansiveness: String,
        context: String?
    ) -> String {
        
        // Opening based on tone
        let opening: String
        switch tone {
        case "formal":
            opening = "Almighty and Everlasting God,"
        case "contemplative":
            opening = "In the quiet of this moment, Lord,"
        case "joyful":
            opening = "Loving Father, with a heart full of joy,"
        default: // conversational
            opening = "Dear Lord,"
        }
        
        // Prayer type specific content
        let typeContent: String
        let itemsList = items.joined(separator: ", ")
        
        switch type {
        case "gratitude":
            typeContent = "I come before you with a heart full of thanksgiving. I am grateful for \(itemsList), and for the countless blessings You have poured into my life."
        case "intercession":
            typeContent = "I lift up \(itemsList) to You today. I ask that You would surround them with Your love, provide for their needs, and grant them Your peace."
        case "petition":
            typeContent = "I bring my requests before You concerning \(itemsList). I ask for Your guidance, provision, and intervention in these matters."
        case "confession":
            typeContent = "I come before You in humility, acknowledging my need for Your grace. I seek Your forgiveness and restoration as I reflect on \(itemsList)."
        case "praise":
            typeContent = "I glorify Your name and magnify Your greatness. As I think of \(itemsList), I am reminded of Your faithfulness and Your unchanging love."
        default:
            typeContent = "I bring \(itemsList) before You in prayer today."
        }
        
        // Middle content based on expansiveness
        let middleContent: String
        switch expansiveness {
        case "concise":
            middleContent = context ?? "Grant Your wisdom and peace."
        case "expansive":
            let contextual = context ?? "I trust in Your perfect timing and Your sovereign plan"
            middleContent = """
            \(contextual)
            
            As I meditate on Your word and seek Your face, I am reminded that You are the God who sees, who knows, and who cares deeply for each of us. Your mercies are new every morning, and Your faithfulness extends to all generations.
            """
        default: // balanced
            let contextual = context ?? "I place my trust in You"
            middleContent = """
            \(contextual)
            
            May Your will be done in all things. Help me to remain steadfast in faith and to trust in Your perfect plan.
            """
        }
        
        // Length-based extension
        let lengthExtension: String
        switch length {
        case "brief":
            lengthExtension = ""
        case "extended":
            lengthExtension = """
            
            Lord, I know that You work all things together for good for those who love You. As I continue to seek Your face and walk in Your ways, I ask that You would strengthen my faith and deepen my trust in You.
            
            May Your presence be felt by all those I have lifted up today. Comfort the hurting, guide the lost, and bring hope to the weary.
            """
        default: // standard
            lengthExtension = """
            
            Strengthen our hearts and guide our steps as we walk in Your ways.
            """
        }
        
        // Closing based on tone
        let closing: String
        switch tone {
        case "formal":
            closing = "We ask this in the name of Christ our Lord, Amen."
        case "joyful":
            closing = "With thanksgiving and praise, Amen!"
        default:
            closing = "In Your holy name, Amen."
        }
        
        // Assemble prayer
        return """
        \(opening)
        
        \(typeContent)
        
        \(middleContent)\(lengthExtension)
        
        \(closing)
        """
    }
    
    // MARK: - Update Prayer
    
    func updatePrayer(id: String, title: String?, text: String?, category: String?, completion: @escaping (Result<Prayer, PrayerAPIError>) -> Void) {
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
        
        guard let request = createAuthorizedRequest(url: url, method: "DELETE") else {
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
    
    // MARK: - Record Playback
    
    func recordPlayback(id: String, completion: @escaping (Result<Prayer, PrayerAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/prayers/\(id)/play") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = createAuthorizedRequest(url: url, method: "POST") else {
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
        
        guard let request = createAuthorizedRequest(url: url) else {
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
