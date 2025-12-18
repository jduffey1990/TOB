//
//  SettingsAPIService.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/16/25.
//  API service for user settings
//

import Foundation

// MARK: - Error Types

enum SettingsAPIError: Error {
    case unauthorized
    case networkError(String)
    case serverError(String)
    case decodingError
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .unauthorized:
            return "Please log in again"
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

// MARK: - Settings API Service

class SettingsAPIService {
    static let shared = SettingsAPIService()
    
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
    
    // MARK: - Get Settings
    
    func fetchSettings(completion: @escaping (Result<UserSettings, SettingsAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/me/settings") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard let request = createAuthorizedRequest(url: url) else {
            completion(.failure(.unauthorized))
            return
        }
        
        print("🔵 Fetching settings from: \(url)")
        
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
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let settings = try decoder.decode(UserSettings.self, from: data)
                    print("✅ Fetched settings: voice=\(settings.voiceIndex), rate=\(settings.playbackRate)")
                    completion(.success(settings))
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
    
    // MARK: - Update Settings
    
    func updateSettings(voiceIndex: Int? = nil, playbackRate: Double? = nil, completion: @escaping (Result<User, SettingsAPIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/me/settings") else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        guard var request = createAuthorizedRequest(url: url, method: "PATCH") else {
            completion(.failure(.unauthorized))
            return
        }
        
        // Build payload with only provided values
        var payload: [String: Any] = [:]
        if let voiceIndex = voiceIndex {
            payload["voiceIndex"] = voiceIndex
        }
        if let playbackRate = playbackRate {
            payload["playbackRate"] = playbackRate
        }
        
        guard !payload.isEmpty else {
            completion(.failure(.networkError("No settings to update")))
            return
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(.networkError("Failed to encode request")))
            return
        }
        
        print("🔵 Updating settings: \(payload)")
        
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
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    decoder.dateDecodingStrategy = .iso8601
                    let user = try decoder.decode(User.self, from: data)
                    print("✅ Updated settings successfully")
                    completion(.success(user))
                } catch {
                    print("❌ Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response: \(jsonString)")
                    }
                    completion(.failure(.decodingError))
                }
                
            case 401:
                completion(.failure(.unauthorized))
                
            case 400:
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
}
