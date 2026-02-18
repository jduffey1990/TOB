//
//  DefaultPrayersView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//  Updated by Jordan Duffey on 12/15/25
//  Pre-built prayer templates
//

import SwiftUI

struct DefaultPrayersView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showingPrayerDetail: PrayerTemplate? = nil
    
    private var categories: [String] {
        DefaultPrayers.categories
    }
    
    private var filteredTemplates: [PrayerTemplate] {
        var filtered = DefaultPrayers.all
        
        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search prayers...", text: $searchText)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryChip(
                            title: "All",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Templates list
                if filteredTemplates.isEmpty {
                    emptyState
                } else {
                    templatesList
                }
            }
            .navigationTitle("Prayer Templates")
        }
        .sheet(item: $showingPrayerDetail) { template in
            PrayerDetailView(template: template, prayerManager: prayerManager)
        }
    }
    
    // MARK: - Subviews
    
    private var templatesList: some View {
        List {
            ForEach(filteredTemplates) { template in
                Button(action: {
                    showingPrayerDetail = template
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(template.text)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        Text(template.category)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.3))
            
            Text("No Templates Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Category Chip Component

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

// MARK: - Prayer Detail Sheet

struct PrayerDetailView: View {
    let template: PrayerTemplate
    @ObservedObject var prayerManager: PrayerManager
    @Environment(\.dismiss) var dismiss
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category badge
                    Text(template.category)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    // Title
                    Text(template.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Prayer text
                    Text(template.text)
                        .font(.body)
                        .lineSpacing(6)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    // Add to My Prayers button
                    Button(action: usePrayer) {
                        Label("Add to My Prayers", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Prayer Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Prayer Added!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("'\(template.title)' has been added to your prayers")
            }
        }
    }
    
    private func usePrayer() {

        prayerManager.addPrayer(title: template.title,text: template.text) { result in
            switch result {
            case .success:
                showingSuccess = true
            case .failure(let error):
                // Error is handled by prayerManager.errorMessage
                print("Failed to add prayer: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview

struct DefaultPrayersView_Previews: PreviewProvider {
    static var previews: some View {
        DefaultPrayersView()
            .environmentObject(PrayerManager.shared)
    }
}
