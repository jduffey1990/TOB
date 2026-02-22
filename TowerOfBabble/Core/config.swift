//
//  config.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/8/25.
//

import Foundation

enum AppEnvironment {  // ← Changed from "Environment" to "AppEnvironment"
    case development
    case production
    
    // Automatically detect based on build configuration
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

struct Config {
    static var baseURL: String {
        switch AppEnvironment.current {  // ← Updated reference
        case .development:
            // For iOS Simulator, use localhost
            // For real device testing, use your computer's local IP (e.g., "http://192.168.1.100:3004")
            return "http://localhost:3004"
        case .production:
            return "https://mvefj6j1bh.execute-api.us-east-2.amazonaws.com" //
        }
    }
    
    // Optional: Add other environment-specific configs
    static var isDebugMode: Bool {
        return AppEnvironment.current == .development
    }
    
    static var apiTimeout: TimeInterval {
        switch AppEnvironment.current {
        case .development:
            return 30.0 // Longer timeout for local development
        case .production:
            return 10.0
        }
    }
}

// MARK: - Usage Example
/*
 In AuthService.swift, replace:
 
     private let baseURL = "https://your-api-url.com"
 
 With:
 
     private let baseURL = Config.baseURL
 
 Now it will automatically use:
 - localhost:3004 when running in Xcode (Debug builds)
 - Your AWS production URL when built for TestFlight/App Store (Release builds)
*/
