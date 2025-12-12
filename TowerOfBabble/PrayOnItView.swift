//
//  PrayOnItView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//

//
//  PrayOnItView.swift
//  TowerOfBabble
//
//  List of people/situations to pray for (MOCKED DATA)
//

import SwiftUI

struct PrayOnItView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @State private var mockItems: [MockPrayOnItItem] = [
        MockPrayOnItItem(name: "Mom", category: "Family", relationship: "Mother"),
        MockPrayOnItItem(name: "Sarah", category: "Friends", relationship: "Best friend"),
        MockPrayOnItItem(name: "Job Interview", category: "Personal", relationship: nil),
        MockPrayOnItItem(name: "Dad's Health", category: "Health", relationship: "Father"),
        MockPrayOnItItem(name: "Church Community", category: "World", relationship: nil),
    ]
    @State private var showingAddItem = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if mockItems.isEmpty {
                    emptyState
                } else {
                    itemsList
                }
                
                // Floating info banner
                VStack {
                    Spacer()
                    mockDataBanner
                        .padding(.bottom, 80) // Above tab bar
                }
            }
            .navigationTitle("Pray On It")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                Text("Add Pray On It Item\n(Coming Soon)")
                    .font(.title3)
                    .padding()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var itemsList: some View {
        List {
            // Info section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("What's this?")
                            .font(.headline)
                    }
                    
                    Text("Add people, situations, and intentions here. When you create a prayer with AI, it can pull from this list to personalize your prayer.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // Grouped by category
            ForEach(MockPrayOnItCategory.allCases, id: \.self) { category in
                let categoryItems = mockItems.filter { $0.category == category.rawValue }
                
                if !categoryItems.isEmpty {
                    Section(header: Text(category.rawValue)) {
                        ForEach(categoryItems) { item in
                            prayOnItRow(item)
                        }
                        .onDelete { offsets in
                            deleteItems(at: offsets, in: category)
                        }
                    }
                }
            }
            
            // Tier limit info
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Free tier: 5 items max")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(mockItems.count)/5")
                        .font(.caption)
                        .foregroundColor(mockItems.count >= 5 ? .red : .secondary)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func prayOnItRow(_ item: MockPrayOnItItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.headline)
            
            if let relationship = item.relationship {
                Text(relationship)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.3))
            
            Text("No Intentions Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("Add people and situations you want to pray for. The AI will use this list when creating personalized prayers.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingAddItem = true }) {
                Label("Add First Item", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
    }
    
    private var mockDataBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Mock data - Backend API coming soon")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func deleteItems(at offsets: IndexSet, in category: MockPrayOnItCategory) {
        let categoryItems = mockItems.filter { $0.category == category.rawValue }
        for offset in offsets {
            if let item = categoryItems[safe: offset],
               let index = mockItems.firstIndex(where: { $0.id == item.id }) {
                mockItems.remove(at: index)
            }
        }
    }
}

// MARK: - Mock Data Models

struct MockPrayOnItItem: Identifiable {
    let id = UUID()
    var name: String
    var category: String
    var relationship: String?
}

enum MockPrayOnItCategory: String, CaseIterable {
    case family = "Family"
    case friends = "Friends"
    case work = "Work"
    case health = "Health"
    case personal = "Personal"
    case world = "World"
    case other = "Other"
}

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

struct PrayOnItView_Previews: PreviewProvider {
    static var previews: some View {
        PrayOnItView()
            .environmentObject(PrayerManager())
    }
}
