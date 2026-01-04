//
//  MainTabView.swift.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//
//
//  Bottom tab navigation (Strava-style) with 5 main sections
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject private var prayerManager = PrayerManager.shared
    @ObservedObject private var prayOnItManager = PrayOnItManager.shared
    @State private var selectedTab = 4 // Start on "My Prayers" tab
    @State private var showingAddPrayer = false       // AI builder
    @State private var showingManualEntry = false     // Direct to PrayerEditorView
    @State private var showingUpgradeSheet = false    // Upgrade prompt
    @State private var showingOutOfAISheet = false
    @State private var upgradeReason: UpgradeReason = .premiumFeature
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content based on selected tab
            TabView(selection: $selectedTab) {
                // Tab 1: Pray On It
                PrayOnItView()
                    .environmentObject(prayerManager)
                    .tag(1)
                
                // Tab 2: Default Prayers
                DefaultPrayersView()
                    .environmentObject(prayerManager)
                    .tag(2)
                
                // Tab 3: Spacer for center + button
                Color.clear
                    .tag(3)
                
                // Tab 4: My Prayers
                PrayersListView()
                    .environmentObject(prayerManager)
                    .tag(4)
                
                // Tab 5: Settings
                SettingsView()
                    .environmentObject(prayerManager)
                    .environmentObject(prayOnItManager) 
                    .tag(5)
            }
            .tabViewStyle(.automatic)
            
            // Custom Tab Bar
            customTabBar
        }
        .sheet(isPresented: $showingAddPrayer) {
            AddPrayerView()
                .environmentObject(prayerManager)
                .environmentObject(prayOnItManager) 
        }
        .sheet(isPresented: $showingUpgradeSheet) {
            UpgradePlaceholderView(reason: upgradeReason)
        }
        .sheet(isPresented: $showingOutOfAISheet) {
            NavigationView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 80))
                        .foregroundColor(.blue.opacity(0.3))
                    
                    // Title
                    Text("Out of AI Generations")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Message
                    Text("You've used all your AI prayer generations for this month.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("You can still create prayers by typing them manually, or upgrade for more AI generations.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Primary: Create Manually
                        Button(action: {
                            showingOutOfAISheet = false
                            // Small delay so sheets don't conflict
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingManualEntry = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Create Prayer Manually")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        // Secondary: Upgrade
                        Button(action: {
                            showingOutOfAISheet = false
                            upgradeReason = .aiCreditsExhausted
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingUpgradeSheet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Upgrade for More AI")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                .padding(.top, 40)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            showingOutOfAISheet = false
                        }
                    }
                }
            }
        }

        // Add sheet for manual entry
        .sheet(isPresented: $showingManualEntry) {
            PrayerEditorView(prayer: nil)
                .environmentObject(prayerManager)
        }
        .ignoresSafeArea(.keyboard) // Prevent tab bar from moving with keyboard
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            // Tab 1: Pray On It
            TabBarButton(
                icon: "list.bullet.clipboard",
                title: "Pray On It",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            // Tab 2: Default Prayers
            TabBarButton(
                icon: "book.closed",
                title: "Templates",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            
            // Center + Button
            Spacer()
                .frame(width: 80) // Space for floating button
            
            // Tab 4: My Prayers
            TabBarButton(
                icon: "text.alignleft",
                title: "My Prayers",
                isSelected: selectedTab == 4
            ) {
                selectedTab = 4
            }
            
            // Tab 5: Settings
            TabBarButton(
                icon: "gearshape",
                title: "Settings",
                isSelected: selectedTab == 5
            ) {
                selectedTab = 5
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 20) // Extra padding for home indicator
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
        .overlay(
            // Floating + button
            Button(action: {
                if !prayerManager.canCreateMorePrayers {
                    upgradeReason = .prayerLimitReached  // Set reason
                    showingUpgradeSheet = true
                    return
                }
                
                if !prayerManager.hasAICredits {
                    upgradeReason = .aiCreditsExhausted
                    showingOutOfAISheet = true
                } else {
                    showingAddPrayer = true
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color.blue)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
            }
            .offset(y: -32) // Raise it above the tab bar
        )
    }
}

// MARK: - Tab Bar Button Component

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .frame(height: 24)
                
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
