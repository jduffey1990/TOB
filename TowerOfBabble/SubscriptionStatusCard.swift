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
            
            // AI Generation stats
            if let ai = aiStats {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("AI Generations", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(ai.displayText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress bar (only if capped)
                    if let _ = ai.limit {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(aiProgressColor)
                                    .frame(width: geometry.size.width * aiProgress, height: 6)
                                    .animation(.easeInOut, value: aiProgress)
                            }
                        }
                        .frame(height: 6)
                    }
                }
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
    
    private var aiStats: PrayerStatsResponse.AIGenerationStats? {
        stats?.aiGenerations
    }

    private var aiProgress: Double {
        guard let limit = aiStats?.limit, limit > 0 else { return 1.0 }
        return Double(aiStats?.current ?? 0) / Double(limit)
    }

    private var aiProgressColor: Color {
        if aiProgress >= 1.0 {
            return .red
        } else if aiProgress >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }

}

// MARK: - Preview

struct SubscriptionStatusCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {

            // Free tier at prayer limit
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
                    ),
                    aiGenerations: PrayerStatsResponse.AIGenerationStats(
                        current: 3,
                        limit: 3,
                        remaining: 0,
                        canGenerate: false,
                        period: "monthly"
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
                    ),
                    aiGenerations: PrayerStatsResponse.AIGenerationStats(
                        current: 1,
                        limit: 3,
                        remaining: 2,
                        canGenerate: true,
                        period: "monthly"
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
                        limit: 20,
                        remaining: 8,
                        canCreate: true
                    ),
                    aiGenerations: PrayerStatsResponse.AIGenerationStats(
                        current: 7,
                        limit: 20,
                        remaining: 13,
                        canGenerate: true,
                        period: "monthly"
                    )
                ),
                onUpgradeTapped: {}
            )

            // Prayer Warrior (daily AI cap)
            SubscriptionStatusCard(
                stats: PrayerStatsResponse(
                    tier: "warrior",
                    isActive: true,
                    expiresAt: nil,
                    prayers: PrayerStatsResponse.PrayerStats(
                        current: 42,
                        limit: 100,
                        remaining: 58,
                        canCreate: true
                    ),
                    aiGenerations: PrayerStatsResponse.AIGenerationStats(
                        current: 3,
                        limit: 3,
                        remaining: 0,
                        canGenerate: false,
                        period: "daily"
                    )
                ),
                onUpgradeTapped: {}
            )

            // Lifetime (unlimited)
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
                    ),
                    aiGenerations: PrayerStatsResponse.AIGenerationStats(
                        current: 12,
                        limit: nil,
                        remaining: nil,
                        canGenerate: true,
                        period: "monthly"
                    )
                ),
                onUpgradeTapped: {}
            )

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

