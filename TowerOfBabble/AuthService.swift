import Foundation

// MARK: - Models

struct LoginResponse: Codable {
    let token: String
    let user: User
}

struct User: Codable {
    let id: String
    let email: String
    let name: String
    let status: String
    let subscriptionTier: String
    let subscriptionExpiresAt: String?
    let settings: UserSettings  // ✅ FIXED: Properly typed
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, status, settings, createdAt, updatedAt
        case subscriptionTier = "subscriptionTier"
        case subscriptionExpiresAt = "subscriptionExpiresAt"
    }
}

enum AuthError: Error {
    case invalidCredentials
    case userInactive
    case networkError(String)
    case serverError(String)
    case decodingError
    case unknown
}

// MARK: - Auth Service

class AuthService {
    static let shared = AuthService()
    
    // Automatically uses localhost in debug, production URL in release
    private let baseURL = Config.baseURL
    
    private init() {}
    
    // MARK: - Login
    
    func login(email: String, password: String, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {
        print("🔵 Starting login...")
        print("🔵 Base URL: \(baseURL)")
        print("🔵 Email: \(email)")
        guard let url = URL(string: "\(baseURL)/login") else {
            print("❌ Invalid URL: \(baseURL)/login")
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        print("🔵 URL is valid: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("🔵 Request body created")
        } catch {
            print("❌ Failed to encode request: \(error)")
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        print("🔵 Starting URLSession task...")
        URLSession.shared.dataTask(with: request) { data, response, error in
            print("🔵 URLSession completed")

            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            print("🔵 Got response")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Not an HTTP response")
                completion(.failure(.unknown))
                return
            }
            
            print("🔵 Status code: \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(.networkError("No data received")))
                return
            }
            
            print("🔵 Data received: \(data.count) bytes")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔵 Response body: \(jsonString)")
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                do {
                    print("🔵 200 OK - attempting to decode")
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    completion(.success(loginResponse))
                } catch {
                    print("❌ Decoding error: \(error)")
                    if let decodingError = error as? DecodingError {
                        print("❌ Detailed decoding error: \(decodingError)")
                    }
                    completion(.failure(.decodingError))
                }
                
            case 401:
                completion(.failure(.invalidCredentials))
                
            case 403:
                // User account inactive
                completion(.failure(.userInactive))
                
            default:
                // Try to parse error message from server
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.serverError("Server error: \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }
    
    // MARK: - Create User
    
    func createUser(email: String, password: String, name: String, completion: @escaping (Result<User, AuthError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/create-user") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "name": name
            // captchaToken is optional - not implementing for now
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
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
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 201:
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    completion(.success(user))
                } catch {
                    print("❌ Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response: \(jsonString)")
                    }
                    completion(.failure(.decodingError))
                }
                
            case 409:
                // Duplicate email
                completion(.failure(.serverError("An account with this email already exists")))
                
            case 400:
                // Validation error
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.serverError("Invalid request")))
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
    
    // MARK: - Helper Methods
    
    func isLoggedIn() -> Bool {
        return UserDefaults.standard.string(forKey: "authToken") != nil
    }
    
    func getCurrentUser() -> User? {
        guard let id = UserDefaults.standard.string(forKey: "userId"),
              let email = UserDefaults.standard.string(forKey: "userEmail"),
              let name = UserDefaults.standard.string(forKey: "userName") else {
            return nil
        }
        
        // Optional fields with defaults (outside the guard)
        let status = UserDefaults.standard.string(forKey: "userStatus") ?? "active" // ✅ Works here
        let tier = UserDefaults.standard.string(forKey: "userTier") ?? "free"

        // Load settings from PrayerManager singleton
        let settings = PrayerManager.shared.settings
        
        return User(
            id: id,
            email: email,
            name: name,
            status: status,
            subscriptionTier: tier,
            subscriptionExpiresAt: UserDefaults.standard.string(forKey: "userSubscriptionExpiresAt"),
            settings: settings,
            createdAt: UserDefaults.standard.string(forKey: "userCreatedAt") ?? "",
            updatedAt: UserDefaults.standard.string(forKey: "userUpdatedAt") ?? ""
        )
    }
    
    func logout() {
        // Clear all user data
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userStatus")
        UserDefaults.standard.removeObject(forKey: "userTier")
        UserDefaults.standard.removeObject(forKey: "userSubscriptionExpiresAt")
        UserDefaults.standard.removeObject(forKey: "userCreatedAt")
        UserDefaults.standard.removeObject(forKey: "userUpdatedAt")
    }
}
