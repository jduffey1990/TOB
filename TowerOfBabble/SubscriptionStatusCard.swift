//
//  SubscriptionStatusCard.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//
//
//  A card banner showing prayer count, tier, and upgrade CTA
//

import SwiftUI

struct SubscriptionStatusCard: View {
    let stats: PrayerStatsResponse?
    let onUpgradeTapped: () -> Void
    
    private var tierName: String {
        guard let stats = stats else { return "Free Plan" }
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
        guard let stats = stats else { return .gray }
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
    
    private var currentCount: Int {
        stats?.prayers.current ?? 0
    }
    
    private var limit: Int? {
        stats?.prayers.limit
    }
    
    private var progress: Double {
        guard let limit = limit, limit > 0 else { return 1.0 }
        return Double(currentCount) / Double(limit)
    }
    
    private var shouldShowUpgrade: Bool {
        guard let stats = stats else { return false }
        return stats.tier.lowercased() == "free"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Top row: Tier name and count
            HStack {
                // Tier badge
                HStack(spacing: 4) {
                    Image(systemName: tierIcon)
                        .font(.caption)
                    Text(tierName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(tierColor)
                
                Spacer()
                
                // Prayer count
                if let limit = limit {
                    Text("\(currentCount)/\(limit) Prayers")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                } else {
                    Text("\(currentCount) Prayers")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            // Progress bar (only show if there's a limit)
            if let limit = limit {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * progress, height: 8)
                            .animation(.easeInOut, value: progress)
                    }
                }
                .frame(height: 8)
            }
            
            // Upgrade CTA (only for free tier)
            if shouldShowUpgrade {
                Button(action: onUpgradeTapped) {
                    HStack {
                        Text(upgradeMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Computed Properties
    
    private var tierIcon: String {
        guard let stats = stats else { return "circle" }
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
    
    private var progressColor: Color {
        if progress >= 1.0 {
            return .red // At or over limit
        } else if progress >= 0.8 {
            return .orange // Getting close
        } else {
            return tierColor // Normal
        }
    }
    
    private var upgradeMessage: String {
        if progress >= 1.0 {
            return "Prayer limit reached • Upgrade to Pro for 50 prayers"
        } else if progress >= 0.8 {
            return "Running low on prayer slots • Upgrade to Pro"
        } else {
            return "Upgrade to Pro for 50 prayers"
        }
    }
}

// MARK: - Preview

struct SubscriptionStatusCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Free tier at limit
            SubscriptionStatusCard(
                stats: PrayerStatsResponse(
                    tier: "free",
                    isActive: true,
                    expiresAt: nil,
                    prayers: PrayerStatsResponse.PrayerStats(
                        current: 5,
                        limit: 5,
                        remaining: 0,
                        canCreate: false
                    )
                ),
                onUpgradeTapped: {}
            )
            
            // Free tier with room
            SubscriptionStatusCard(
                stats: PrayerStatsResponse(
                    tier: "free",
                    isActive: true,
                    expiresAt: nil,
                    prayers: PrayerStatsResponse.PrayerStats(
                        current: 2,
                        limit: 5,
                        remaining: 3,
                        canCreate: true
                    )
                ),
                onUpgradeTapped: {}
            )
            
            // Pro tier
            SubscriptionStatusCard(
                stats: PrayerStatsResponse(
                    tier: "pro",
                    isActive: true,
                    expiresAt: nil,
                    prayers: PrayerStatsResponse.PrayerStats(
                        current: 12,
                        limit: 50,
                        remaining: 38,
                        canCreate: true
                    )
                ),
                onUpgradeTapped: {}
            )
            
            // Prayer Warrior (unlimited)
            SubscriptionStatusCard(
                stats: PrayerStatsResponse(
                    tier: "lifetime",
                    isActive: true,
                    expiresAt: nil,
                    prayers: PrayerStatsResponse.PrayerStats(
                        current: 127,
                        limit: nil,
                        remaining: nil,
                        canCreate: true
                    )
                ),
                onUpgradeTapped: {}
            )
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}
