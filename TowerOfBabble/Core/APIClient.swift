//
//  APIClient.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 1/5/26.
//  Shared utility for making authorized API requests
//  Used by all API service classes to avoid code duplication
//

import Foundation

class APIClient {
    
    // MARK: - Singleton
    
    static let shared = APIClient()
    
    private init() {}
    
    // MARK: - Request Creation
    
    /// Create an authorized request with JWT token
    func createAuthorizedRequest(url: URL, method: String = "GET") -> URLRequest? {
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
    
    // MARK: - Optional: Future Enhancements
    
    // You could add in the future:
    // - func retryRequest()
    // - func logRequest()
    // - func handleCommonErrors()
}
