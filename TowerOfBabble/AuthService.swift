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
    let settings: UserSettingsModel
    let denomination: String  // NEW: User's religious denomination
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case status
        case subscriptionTier
        case subscriptionExpiresAt
        case settings
        case denomination
        case createdAt
        case updatedAt
    }
}

// NEW: Response model for GET /denominations
struct DenominationsResponse: Codable {
    let denominations: [String]
    let count: Int
}

enum AuthError: Error {
    case invalidCredentials
    case userInactive
    case networkError(String)
    case serverError(String)
    case decodingError
    case unknown
    case unauthorized
}

// MARK: - Auth Service

class AuthService {
    static let shared = AuthService()
    
    // Automatically uses localhost in debug, production URL in release
    private let baseURL = Config.baseURL
    
    private init() {}
    
    // MARK: - Login
    
    func login(email: String, password: String, completion: @escaping (Result<LoginResponse, AuthError>) -> Void) {

        guard let url = URL(string: "\(baseURL)/login") else {
            print("❌ Invalid URL: \(baseURL)/login")
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Failed to encode request: \(error)")
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Not an HTTP response")
                completion(.failure(.unknown))
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(.networkError("No data received")))
                return
            }
            
            
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
    
    func createUser(
        email: String,
        password: String,
        name: String,
        denomination: String,  // NEW: Required denomination parameter
        completion: @escaping (Result<User, AuthError>) -> Void)
    {
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
            "name": name,
            "denomination": denomination  // NEW: Include denomination
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
    
    // MARK: - Fetch Denominations
        
    // NEW: Fetch denominations list from backend
    func fetchDenominations(completion: @escaping (Result<[String], AuthError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/denominations") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                completion(.failure(.networkError("Invalid response")))
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let denominationsResponse = try JSONDecoder().decode(DenominationsResponse.self, from: data)
                    completion(.success(denominationsResponse.denominations))
                } catch {
                    print("❌ Decoding error: \(error)")
                    completion(.failure(.decodingError))
                }
            } else {
                completion(.failure(.serverError("Server error: \(httpResponse.statusCode)")))
            }
        }.resume()
    }
    
    // MARK: - Update User Denomination
        
        
    func updateDenomination(
        denomination: String,
        completion: @escaping (Result<User, AuthError>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/edit-user") else{
            completion(.failure(.networkError("Invalid URL or no auth token")))
            return
        }
        
        guard var request = APIClient.shared.createAuthorizedRequest(url: url, method: "PATCH") else {
            completion(.failure(.unauthorized))
            return
        }
        
        
        let body: [String: Any] = ["denomination": denomination]
        
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
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                completion(.failure(.networkError("Invalid response")))
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    completion(.success(user))
                } catch {
                    completion(.failure(.decodingError))
                }
            } else {
                if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorData["error"] {
                    completion(.failure(.serverError(errorMessage)))
                } else {
                    completion(.failure(.serverError("Server error: \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }

    // MARK: - Password Reset

    func requestPasswordReset(email: String, completion: @escaping (Result<String, AuthError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/request-password-reset") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email
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
            case 200:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.success(message))
                } else {
                    completion(.success("Password reset email sent!"))
                }
                
            case 429:
                // Too many requests
                completion(.failure(.serverError("Please wait before requesting another password reset")))
                
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

    func resetPassword(token: String, newPassword: String, completion: @escaping (Result<String, AuthError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/reset-password") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "token": token,
            "newPassword": newPassword
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
            case 200:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    completion(.success(message))
                } else {
                    completion(.success("Password reset successfully!"))
                }
                
            case 400:
                // Validation error or invalid token
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    completion(.failure(.serverError(message)))
                } else {
                    completion(.failure(.serverError("Invalid or expired reset token")))
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
       
       // Optional fields with defaults
       let status = UserDefaults.standard.string(forKey: "userStatus") ?? "active"
       let tier = UserDefaults.standard.string(forKey: "userTier") ?? "free"
       let denomination = UserDefaults.standard.string(forKey: "userDenomination") ?? ""  // FIXED: Load denomination
       
       // Load settings from UserSettings singleton
       let settings = UserSettings.shared.settings
       
       return User(
           id: id,
           email: email,
           name: name,
           status: status,
           subscriptionTier: tier,
           subscriptionExpiresAt: UserDefaults.standard.string(forKey: "userSubscriptionExpiresAt"),
           settings: settings,
           denomination: denomination,  // FIXED: Include denomination
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
        UserDefaults.standard.removeObject(forKey: "userDenomination")
        UserDefaults.standard.removeObject(forKey: "userCreatedAt")
        UserDefaults.standard.removeObject(forKey: "userUpdatedAt")
        
        UserSettings.shared.resetToDefaults()
    }
}
