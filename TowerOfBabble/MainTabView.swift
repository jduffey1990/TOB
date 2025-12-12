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
    @StateObject private var prayerManager = PrayerManager()
    @State private var selectedTab = 3 // Start on "My Prayers" tab
    @State private var showingAddPrayer = false
    
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
                    .tag(5)
            }
            .tabViewStyle(.automatic)
            
            // Custom Tab Bar
            customTabBar
        }
        .sheet(isPresented: $showingAddPrayer) {
            AddPrayerView()
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
                showingAddPrayer = true
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
