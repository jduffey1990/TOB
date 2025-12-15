//
//  SettingsView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//
//  User settings and subscription management
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @State private var showingLogoutAlert = false
    @State private var showingUpgradeSheet = false
    @State private var upgradeReason: UpgradeReason = .premiumFeature
    
    var body: some View {
        NavigationView {
            List {
                // User Section
                Section {
                    if let user = AuthService.shared.getCurrentUser() {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Subscription Section
                Section(header: Text("Subscription")) {
                    subscriptionRow
                    
                    if prayerManager.prayerStats?.tier.lowercased() == "free" {
                        Button(action: {
                            showingUpgradeSheet = true
                        }) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Upgrade to Pro")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Usage Stats
                Section(header: Text("Usage")) {
                    if let stats = prayerManager.prayerStats {
                        HStack {
                            Image(systemName: "text.alignleft")
                            Text("Saved Prayers")
                            Spacer()
                            if let limit = stats.prayers.limit {
                                Text("\(stats.prayers.current)/\(limit)")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(stats.prayers.current)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "sparkles")
                            Text("AI Generations")
                            Spacer()
                            Text("Coming Soon")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                            Text("Pray On It Items")
                            Spacer()
                            Text("Coming Soon")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            ProgressView()
                            Text("Loading stats...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Voice Settings
                Section(header: Text("Playback")) {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                        Text("Voice Selection")
                        Spacer()
                        Text("iOS Native")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "speedometer")
                        Text("Playback Speed")
                        Spacer()
                        Text("Normal")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                // App Info
                Section(header: Text("About")) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                // Actions
                Section {
                    Button(action: {
                        prayerManager.refresh()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Data")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showingLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .sheet(isPresented: $showingUpgradeSheet) {
                UpgradePlaceholderView(reason: upgradeReason)
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var subscriptionRow: some View {
        HStack {
            // Tier icon
            Image(systemName: tierIcon)
                .font(.title2)
                .foregroundColor(tierColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tierName)
                    .font(.headline)
                
                if let stats = prayerManager.prayerStats {
                    if stats.tier.lowercased() == "free" {
                        Text("Limited features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let expiresAt = stats.expiresAt {
                        Text("Expires: \(expiresAt)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // Badge
            Text(tierName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(tierColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tierColor.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.vertical, 4)
    }
    
    private var tierName: String {
        guard let stats = prayerManager.prayerStats else { return "Loading..." }
        switch stats.tier.lowercased() {
        case "free":
            return "Free Plan"
        case "pro":
            return "Pro Plan"
        case "lifetime", "warrior":
            return "Prayer Warrior"
        default:
            return stats.tier.capitalized
        }
    }
    
    private var tierColor: Color {
        guard let stats = prayerManager.prayerStats else { return .gray }
        switch stats.tier.lowercased() {
        case "free":
            return .gray
        case "pro":
            return .blue
        case "lifetime", "warrior":
            return .purple
        default:
            return .blue
        }
    }
    
    private var tierIcon: String {
        guard let stats = prayerManager.prayerStats else { return "circle" }
        switch stats.tier.lowercased() {
        case "free":
            return "circle"
        case "pro":
            return "star.circle.fill"
        case "lifetime", "warrior":
            return "crown.fill"
        default:
            return "circle.fill"
        }
    }
    
    // MARK: - Actions
    
    private func logout() {
        AuthService.shared.logout()
        exit(0)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(PrayerManager())
    }
}
