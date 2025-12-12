//
//  PrayersListView.swift
//  TowerOfBabble
//
//  Updated with subscription status card banner
//

import SwiftUI

struct PrayersListView: View {
    @StateObject private var prayerManager = PrayerManager()
    @State private var showingNewPrayer = false
    @State private var showingLogoutAlert = false
    @State private var showingUpgradeSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                mainContent
                
                // Floating + button
                floatingAddButton
            }
            .navigationTitle("My Prayers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    userMenu
                }
            }
            .sheet(isPresented: $showingNewPrayer) {
                PrayerEditorView(prayer: nil)
                    .environmentObject(prayerManager)
            }
            .sheet(isPresented: $showingUpgradeSheet) {
                UpgradePlaceholderView()
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            .alert("Error", isPresented: .constant(prayerManager.errorMessage != nil)) {
                Button("OK") {
                    prayerManager.errorMessage = nil
                }
            } message: {
                if let error = prayerManager.errorMessage {
                    Text(error)
                }
            }
            .refreshable {
                prayerManager.refresh()
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var mainContent: some View {
        if prayerManager.prayers.isEmpty && !prayerManager.isLoading {
            emptyStateView
        } else {
            prayersListWithCard
        }
    }
    
    private var prayersListWithCard: some View {
        List {
            // Subscription status card as first item
            Section {
                SubscriptionStatusCard(
                    stats: prayerManager.prayerStats,
                    onUpgradeTapped: {
                        showingUpgradeSheet = true
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Prayers section
            Section {
                ForEach(prayerManager.prayers) { prayer in
                    prayerRow(prayer)
                }
                .onDelete(perform: deletePrayer)
            }
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
    
    private func prayerRow(_ prayer: Prayer) -> some View {
        NavigationLink(destination:
            PrayerEditorView(prayer: prayer)
                .environmentObject(prayerManager)
        ) {
            VStack(alignment: .leading, spacing: 5) {
                Text(prayer.title)
                    .font(.headline)
                
                Text(prayer.text)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding(.vertical, 5)
        }
    }
    
    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    if prayerManager.canCreateMorePrayers {
                        showingNewPrayer = true
                    } else {
                        showingUpgradeSheet = true
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(prayerManager.canCreateMorePrayers ? Color.blue : Color.gray)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
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
            prayerManager.deletePrayer(prayer)
        }
    }
    
    private func logout() {
        AuthService.shared.logout()
        // Force quit to restart authentication flow
        exit(0)
    }
}

// MARK: - Upgrade Placeholder View

struct UpgradePlaceholderView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Upgrade to Pro")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Get 50 prayer slots, cloud sync, and premium features")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "checkmark.circle.fill", text: "50 saved prayers")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Cloud sync across devices")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Premium voice options")
                    FeatureRow(icon: "checkmark.circle.fill", text: "AI prayer suggestions")
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        // TODO: Implement actual purchase flow
                        print("Annual purchase tapped")
                    }) {
                        VStack(spacing: 4) {
                            Text("$9.99/year")
                                .font(.headline)
                            Text("Save 50%")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // TODO: Implement actual purchase flow
                        print("Monthly purchase tapped")
                    }) {
                        Text("$1.99/month")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

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
    static var previews: some View {
        PrayersListView()
    }
}
