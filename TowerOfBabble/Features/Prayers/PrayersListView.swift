//
//  PrayersListView.swift
//  TowerOfBabble
//
//  Create by Jordan Duffey 12/11/25
//  Updated by Jordan Duffey 12/15/25
//  FIXED: Debug section corrected to use prayerManager
//

import SwiftUI
import StoreKit

struct PrayersListView: View {
    @Binding var selectedTab: Int
    @ObservedObject private var prayerManager = PrayerManager.shared
    @State private var navigationPath = NavigationPath()
    @State private var showingNewPrayer = false
    @State private var showingLogoutAlert = false
    @State private var showingUpgradeSheet = false
    @State private var upgradeReason: UpgradeReason = .premiumFeature
    @State private var searchText = ""
    
    // Computed property for filtered prayers
    private var filteredPrayers: [Prayer] {
        if searchText.isEmpty {
            return prayerManager.prayers
        } else {
            return prayerManager.prayers.filter { prayer in
                prayer.title.localizedCaseInsensitiveContains(searchText) ||
                prayer.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                mainContent
            }
            .navigationTitle("My Prayers")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Prayer.self) { prayer in
                PrayerEditorView(prayer: prayer)
                    .environmentObject(prayerManager)
            }
            .onAppear {
                navigationPath = NavigationPath()
            }
            .onChange(of: selectedTab) { tab in
                if tab == 4 {
                    navigationPath = NavigationPath()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search prayers...")
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var mainContent: some View {
        if prayerManager.prayers.isEmpty && !prayerManager.isLoading {
            emptyStateView
        } else if filteredPrayers.isEmpty && !searchText.isEmpty {
            searchEmptyStateView
        } else {
            prayersListWithCard
        }
    }
    
    private var prayersListWithCard: some View {
        List {
            // Subscription status card as first item (only show when not searching)
            if searchText.isEmpty {
                Section {
                    SubscriptionStatusCard(
                        stats: prayerManager.prayerStats,
                        onUpgradeTapped: {
                            upgradeReason = .prayerLimitReached
                            showingUpgradeSheet = !prayerManager.canCreateMorePrayers
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            
            // Prayers section
            Section {
                if searchText.isEmpty {
                    ForEach(prayerManager.prayers) { prayer in
                        prayerRow(prayer)
                    }
                    .onDelete(perform: deletePrayer)
                } else {
                    // When searching, show filtered results with highlights
                    ForEach(filteredPrayers) { prayer in
                        prayerRow(prayer, highlightSearch: true)
                    }
                }
            } header: {
                if !searchText.isEmpty {
                    Text("\(filteredPrayers.count) result\(filteredPrayers.count == 1 ? "" : "s")")
                }
            }
            
            // ✅ FIXED: Debug section with proper variable references
//            #if DEBUG
//            Section {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("🐛 DEBUG INFO")
//                        .font(.headline)
//                    if let stats = prayerManager.prayerStats {
//                        Text("Can create: \(stats.prayers.canCreate ? "✅ YES" : "❌ NO")")
//                        Text("Current count: \(stats.prayers.current)")
//                        Text("Limit: \(stats.prayers.limit?.description ?? "nil (unlimited)")")
//                        Text("Tier: \(stats.tier)")
//                        Text("Remaining: \(stats.prayers.remaining?.description ?? "unlimited")")
//                    } else {
//                        Text("Stats not loaded yet...")
//                    }
//                    Text("Prayers in UI: \(prayerManager.prayers.count)")
//                }
//                .font(.caption)
//                .padding(.vertical, 4)
//            }
//            .listRowBackground(Color.yellow.opacity(0.2))
//            #endif
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hands.sparkles")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.3))
            
            Text("No Prayers Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("Tap the + button to create your first prayer")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var searchEmptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("No prayers match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func prayerRow(_ prayer: Prayer, highlightSearch: Bool = false) -> some View {
        NavigationLink(value: prayer) {
            VStack(alignment: .leading, spacing: 5) {
                if highlightSearch && !searchText.isEmpty {
                    highlightedText(prayer.title, highlight: searchText)
                        .font(.headline)
                } else {
                    Text(prayer.title)
                        .font(.headline)
                }

                if highlightSearch && !searchText.isEmpty {
                    highlightedText(prayer.text, highlight: searchText)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                } else {
                    Text(prayer.text)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 5)
        }
    }
    // Helper to highlight search text
    private func highlightedText(_ text: String, highlight: String) -> Text {
        var result = Text("")
        let parts = text.components(separatedBy: highlight)
        
        if parts.count > 1 {
            for (index, part) in parts.enumerated() {
                result = result + Text(part)
                if index < parts.count - 1 {
                    result = result + Text(highlight).fontWeight(.bold).foregroundColor(.blue)
                }
            }
        } else {
            // Case-insensitive search
            let range = text.range(of: highlight, options: .caseInsensitive)
            if let range = range {
                let before = String(text[..<range.lowerBound])
                let match = String(text[range])
                let after = String(text[range.upperBound...])
                
                result = Text(before) + Text(match).fontWeight(.bold).foregroundColor(.blue) + Text(after)
            } else {
                result = Text(text)
            }
        }
        
        return result
    }
    
    private var userMenu: some View {
        Menu {
            userMenuContent
        } label: {
            Image(systemName: "person.circle")
                .font(.title3)
        }
    }
    
    @ViewBuilder
    private var userMenuContent: some View {
        if let user = AuthService.shared.getCurrentUser() {
            Text(user.name)
            Text(user.email)
                .font(.caption)
            
            Divider()
        }
        
        Button(action: {
            prayerManager.refresh()
        }) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            showingLogoutAlert = true
        }) {
            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
        }
    }
    
    // MARK: - Actions
    
    private func deletePrayer(at offsets: IndexSet) {
        for index in offsets {
            let prayer = prayerManager.prayers[index]
            prayerManager.deletePrayer(prayer) { result in
                // Only show alert if delete actually failed
                if case .failure(let error) = result {
                    // Could show an alert here if you want
                    print("Failed to delete: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func logout() {
        AuthManager.shared.logout()
        // Force quit to restart authentication flow
        exit(0)
    }
}

// MARK: - Upgrade Placeholder View

// Define the enum
enum UpgradeReason {
    case prayerLimitReached
    case aiCreditsExhausted
    case premiumFeature
}

// Update UpgradePlaceholderView
struct UpgradePlaceholderView: View {
    @Environment(\.dismiss) var dismiss
    let reason: UpgradeReason

    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @State private var selectedBilling: BillingPeriod = .annual
    @State private var purchaseError: String?
    @State private var showingSuccessAlert = false
    @State private var purchasedTierName: String = ""

    enum BillingPeriod {
        case annual, monthly
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Header ──────────────────────────────────────
                    VStack(spacing: 8) {
                        Image(systemName: iconForReason)
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text(titleForReason)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text(messageForReason)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 8)

                    // ── Billing Toggle ───────────────────────────────
                    Picker("Billing", selection: $selectedBilling) {
                        Text("Annual").tag(BillingPeriod.annual)
                        Text("Monthly").tag(BillingPeriod.monthly)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)

                    if selectedBilling == .annual {
                        Text("Save over 50% with annual billing")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }

                    // ── Tier Cards ───────────────────────────────────
                    VStack(spacing: 16) {
                        tierCard(
                            name:       "Pro",
                            color:      .blue,
                            icon:       "star.circle.fill",
                            features:   ["20 saved prayers", "20 AI generations/month", "10 Pray On It items", "Premium voices"],
                            productID:  selectedBilling == .annual
                                            ? TOBProductID.proAnnual
                                            : TOBProductID.proMonthly
                        )

                        tierCard(
                            name:       "Prayer Warrior",
                            color:      .purple,
                            icon:       "crown.fill",
                            features:   ["50 saved prayers", "3 AI generations/day (~90/mo)", "25 Pray On It items", "All voices unlocked"],
                            productID:  selectedBilling == .annual
                                            ? TOBProductID.warriorAnnual
                                            : TOBProductID.warriorMonthly
                        )
                    }
                    .padding(.horizontal, 20)

                    // ── Error ────────────────────────────────────────
                    if let error = purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // ── Restore ──────────────────────────────────────
                    Button(action: restorePurchases) {
                        Text("Restore Purchases")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .disabled(subscriptionService.isPurchasing)
                }
            }
            .alert("Welcome!", isPresented: $showingSuccessAlert) {
                Button("Let's Go!") { dismiss() }
            } message: {
                Text("You're now on the \(purchasedTierName) plan. Enjoy your upgraded experience!")
            }
        }
    }

    // MARK: - Tier Card

    @ViewBuilder
    private func tierCard(
        name:      String,
        color:     Color,
        icon:      String,
        features:  [String],
        productID: TOBProductID
    ) -> some View {
        let product = subscriptionService.product(for: productID)
        let price   = product?.displayPrice ?? "—"
        let suffix  = selectedBilling == .annual ? "/yr" : "/mo"

        VStack(alignment: .leading, spacing: 14) {

            // Card header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(name)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                Text("\(price)\(suffix)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Divider()

            // Feature list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(color)
                            .font(.caption)
                        Text(feature)
                            .font(.subheadline)
                    }
                }
            }

            // Purchase button
            Button(action: { purchase(productID) }) {
                HStack {
                    if subscriptionService.isPurchasing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(subscriptionService.isPurchasing ? "Processing..." : "Subscribe — \(price)\(suffix)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(subscriptionService.isPurchasing || product == nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func purchase(_ productID: TOBProductID) {
        guard let product = subscriptionService.product(for: productID) else {
            purchaseError = "Product unavailable. Check your connection and try again."
            return
        }

        purchaseError = nil

        Task {
            let result = await subscriptionService.purchase(product)

            await MainActor.run {
                switch result {
                case .success(let tier):
                    purchasedTierName = tier == "prayer_warrior" ? "Prayer Warrior" : "Pro"
                    showingSuccessAlert = true

                case .cancelled:
                    break  // User cancelled — no message needed

                case .failed(let error):
                    purchaseError = error.localizedDescription
                }
            }
        }
    }

    private func restorePurchases() {
        Task {
            await subscriptionService.restorePurchases()
            await MainActor.run {
                dismiss()
            }
        }
    }

    // MARK: - Reason-Based Content

    private var iconForReason: String {
        switch reason {
        case .prayerLimitReached:  return "exclamationmark.triangle.fill"
        case .aiCreditsExhausted:  return "sparkles.rectangle.stack"
        case .premiumFeature:      return "star.circle.fill"
        }
    }

    private var titleForReason: String {
        switch reason {
        case .prayerLimitReached:  return "Prayer Limit Reached"
        case .aiCreditsExhausted:  return "Out of AI Credits"
        case .premiumFeature:      return "Upgrade Your Plan"
        }
    }

    private var messageForReason: String {
        switch reason {
        case .prayerLimitReached:
            return "You've hit your free tier limit. Upgrade to save more prayers and unlock premium features."
        case .aiCreditsExhausted:
            return "You've used all your AI generations. Upgrade for more AI-powered prayers."
        case .premiumFeature:
            return "Unlock more prayers, AI generations, and beautiful voices."
        }
    }
}

// MARK: - FeatureRow (keep this — used elsewhere)

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

struct PrayersListView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var selectedTab: Int = 4

        var body: some View {
            PrayersListView(selectedTab: $selectedTab)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}

