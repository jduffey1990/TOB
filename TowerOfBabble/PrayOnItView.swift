//
//  PrayOnItView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//
//  updated by Jordan Duffey on 12/15/25.
//

import SwiftUI

struct PrayOnItView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @State private var items: [PrayOnItItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddItem = false
    @State private var stats: PrayOnItStatsResponse?
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading && items.isEmpty {
                    ProgressView("Loading...")
                } else if items.isEmpty {
                    emptyState
                } else {
                    itemsList
                }
            }
            .navigationTitle("Pray On It")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(stats?.items.canCreate == false)
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddPrayOnItItemView(onItemAdded: {
                    loadItems()
                })
            }
            .onAppear {
                loadItems()
                loadStats()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
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
            ForEach(PrayOnItItem.Category.allCases, id: \.self) { category in
                let categoryItems = items.filter { $0.category == category }
                
                if !categoryItems.isEmpty {
                    Section(header: Text(category.displayName)) {
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
            if let stats = stats {
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        if let limit = stats.items.limit {
                            Text("\(stats.tier.capitalized) tier: \(limit) items max")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(stats.tier.capitalized) tier: Unlimited items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let limit = stats.items.limit {
                            Text("\(stats.items.current)/\(limit)")
                                .font(.caption)
                                .foregroundColor(stats.items.current >= limit ? .red : .secondary)
                        } else {
                            Text("\(stats.items.current)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Upgrade prompt if at limit
                    if stats.items.canCreate == false {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                            Text("Upgrade to add more items")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            loadItems()
            loadStats()
        }
    }
    
    private func prayOnItRow(_ item: PrayOnItItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.headline)
            
            HStack {
                if let relationship = item.relationship {
                    Text(relationship)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let prayerFocus = item.prayerFocus {
                    if item.relationship != nil {
                        Text("•")
                            .foregroundColor(.secondary)
                    }
                    Text(prayerFocus)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if let notes = item.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
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
    
    // MARK: - Actions
    
    private func loadItems() {
        isLoading = true
        
        PrayOnItAPIService.shared.fetchItems { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let itemResponses):
                    self.items = itemResponses.map { $0.toLocalItem() }
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadStats() {
        PrayOnItAPIService.shared.fetchStats { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let statsResponse):
                    self.stats = statsResponse
                    
                case .failure(let error):
                    print("Failed to load stats: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet, in category: PrayOnItItem.Category) {
        let categoryItems = items.filter { $0.category == category }
        
        for offset in offsets {
            guard let item = categoryItems[safe: offset] else { continue }
            
            // Optimistic delete
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
            }
            
            // Call API to delete
            PrayOnItAPIService.shared.deleteItem(id: item.id.uuidString) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Already removed optimistically
                        loadStats() // Refresh stats
                        
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        // Reload to restore deleted item
                        loadItems()
                    }
                }
            }
        }
    }
}

// MARK: - Add Item View (Placeholder)

struct AddPrayOnItItemView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var selectedCategory: PrayOnItItem.Category = .personal
    @State private var relationship = ""
    @State private var prayerFocus = ""
    @State private var notes = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    let onItemAdded: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                        .autocapitalization(.words)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PrayOnItItem.Category.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }
                
                Section("Optional Details") {
                    TextField("Relationship (e.g., Mother, Friend)", text: $relationship)
                        .autocapitalization(.words)
                    
                    TextField("Prayer Focus (e.g., healing, guidance)", text: $prayerFocus)
                        .autocapitalization(.words)
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .autocapitalization(.sentences)
                    
                    Text("\(notes.count)/100")
                        .font(.caption)
                        .foregroundColor(notes.count > 100 ? .red : .secondary)
                }
            }
            .navigationTitle("Add Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        createItem()
                    }
                    .disabled(name.isEmpty || notes.count > 100 || isCreating)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func createItem() {
        isCreating = true
        
        PrayOnItAPIService.shared.createItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory.rawValue,
            relationship: relationship.isEmpty ? nil : relationship.trimmingCharacters(in: .whitespacesAndNewlines),
            prayerFocus: prayerFocus.isEmpty ? nil : prayerFocus.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { result in
            DispatchQueue.main.async {
                isCreating = false
                
                switch result {
                case .success:
                    onItemAdded()
                    dismiss()
                    
                case .failure(let error):
                    if case .limitReached(let message) = error {
                        // Show upgrade prompt
                        errorMessage = message
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
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
