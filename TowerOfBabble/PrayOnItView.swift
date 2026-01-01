//
//  PrayOnItView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//  Updated by Jordan Duffey on 12/15/25.
//

import SwiftUI

struct PrayOnItView: View {
    @ObservedObject private var manager = PrayOnItManager.shared
    @State private var showingAddItem = false
    @State private var editingItem: PrayOnItItem?
    @State private var showingUpgradeSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if manager.isLoading && manager.items.isEmpty {
                    ProgressView("Loading...")
                } else if manager.items.isEmpty {
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
                    .disabled(!manager.canCreateMoreItems)
                }
            }

            .sheet(isPresented: $showingAddItem) {
                AddPrayOnItItemView(manager: manager)
            }
            .sheet(item: $editingItem) { item in
                EditPrayOnItItemView(manager: manager, item: item)
            }
            .sheet(isPresented: $showingUpgradeSheet) {
                PrayOnItUpgradeView()
            }

            .onAppear {
                manager.refresh()
            }
            .alert("Error", isPresented: .constant(manager.errorMessage != nil)) {
                Button("OK") {
                    manager.errorMessage = nil
                }
            } message: {
                if let error = manager.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var itemsList: some View {
        // ADD THIS TEMPORARY DEBUG SECTION
        
        List {
            // Compact counter at top
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(manager.tierDisplayText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !manager.canCreateMoreItems {
                            Button(action: {
                                showingUpgradeSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.caption)
                                    Text("Upgrade for more")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Count display
                    if let limit = manager.limit {
                        Text("\(manager.currentCount)/\(limit)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(manager.currentCount >= limit ? .red : .primary)
                    } else {
                        Text("\(manager.currentCount)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Info section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("What's this?")
                            .font(.headline)
                    }
                    
                    Text("Add common prayer themes here. When you create a prayer with AI, it can pull from this list to personalize your prayer.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🐛 DEBUG INFO")
                        .font(.headline)
                    Text("Can create: \(manager.canCreateMoreItems ? "✅ YES" : "❌ NO")")
                    Text("Current count: \(manager.currentCount)")
                    Text("Limit: \(manager.limit?.description ?? "nil (unlimited)")")
                    Text("Tier: \(manager.stats?.tier ?? "unknown")")
                    Text("Backend canCreate: \(manager.stats?.items.canCreate.description ?? "unknown")")
                    Text("Remaining: \(manager.stats?.items.remaining?.description ?? "nil")")
                }
                .font(.body)
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.yellow.opacity(0.2))
            
            // Grouped by category
            ForEach(PrayOnItItem.Category.allCases, id: \.self) { category in
                let categoryItems = manager.items(for: category)
                
                if !categoryItems.isEmpty {
                    Section(header: Text(category.displayName)) {
                        ForEach(categoryItems) { item in
                            prayOnItRow(item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingItem = item
                                }
                        }
                        .onDelete { offsets in
                            deleteItems(at: offsets, in: category)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            manager.refresh()
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
                    Text(prayerFocus.displayName)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if let notes = item.notes, !notes.isEmpty {
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
    
    private func deleteItems(at offsets: IndexSet, in category: PrayOnItItem.Category) {
        let categoryItems = manager.items(for: category)
        
        for offset in offsets {
            guard let item = categoryItems[safe: offset] else { continue }
            manager.deleteItem(item)
        }
    }
}

// MARK: - Upgrade View

struct PrayOnItUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Pray On It Limit Reached")
                    .font(.system(size: 32, weight: .bold))
                
                Text("You've reached your limit. Upgrade to Pro for 50 intention slots or Prayer Warrior for unlimited!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRowOnIt(icon: "checkmark.circle.fill", text: "50 saved prayers")
                    FeatureRowOnIt(icon: "checkmark.circle.fill", text: "50 Pray On It items (Pro)")
                    FeatureRowOnIt(icon: "checkmark.circle.fill", text: "Unlimited items (Warrior)")
                    FeatureRowOnIt(icon: "checkmark.circle.fill", text: "Cloud sync across devices")
                    FeatureRowOnIt(icon: "checkmark.circle.fill", text: "Premium voice options")
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

struct FeatureRowOnIt: View {
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

// MARK: - Add Item View

struct AddPrayOnItItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: PrayOnItManager
    
    @State private var name = ""
    @State private var selectedCategory: PrayOnItItem.Category = .personal
    @State private var relationship = ""
    @State private var selectedPrayerFocus: PrayOnItItem.PrayerFocus?
    @State private var notes = ""
    @State private var showingLimitAlert = false
    @State private var limitAlertMessage = ""
    
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
                    
                    Picker("Prayer Focus", selection: $selectedPrayerFocus) {
                        Text("None").tag(nil as PrayOnItItem.PrayerFocus?)
                        ForEach(PrayOnItItem.PrayerFocus.allCases, id: \.self) { focus in
                            Text(focus.displayName).tag(focus as PrayOnItItem.PrayerFocus?)
                        }
                    }
                    
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
                    .disabled(manager.isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        createItem()
                    }
                    .disabled(name.isEmpty || notes.count > 100 || manager.isLoading)
                }
            }
            .alert("Limit Reached", isPresented: $showingLimitAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(limitAlertMessage)
            }
        }
    }
    
    private func createItem() {
        manager.addItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory,
            relationship: relationship.isEmpty ? nil : relationship.trimmingCharacters(in: .whitespacesAndNewlines),
            prayerFocus: selectedPrayerFocus,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { result in
            switch result {
            case .success:
                dismiss()
                
            case .failure(let error):
                if case .limitReached(let message) = error {
                    limitAlertMessage = message
                    showingLimitAlert = true
                }
            }
        }
    }
}

// MARK: - Edit Item View

struct EditPrayOnItItemView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: PrayOnItManager
    let item: PrayOnItItem
    
    @State private var name: String
    @State private var selectedCategory: PrayOnItItem.Category
    @State private var relationship: String
    @State private var selectedPrayerFocus: PrayOnItItem.PrayerFocus?
    @State private var notes: String
    
    init(manager: PrayOnItManager, item: PrayOnItItem) {
        self.manager = manager
        self.item = item
        _name = State(initialValue: item.name)
        _selectedCategory = State(initialValue: item.category)
        _relationship = State(initialValue: item.relationship ?? "")
        _selectedPrayerFocus = State(initialValue: item.prayerFocus)
        _notes = State(initialValue: item.notes ?? "")
    }
    
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
                    
                    Picker("Prayer Focus", selection: $selectedPrayerFocus) {
                        Text("None").tag(nil as PrayOnItItem.PrayerFocus?)
                        ForEach(PrayOnItItem.PrayerFocus.allCases, id: \.self) { focus in
                            Text(focus.displayName).tag(focus as PrayOnItItem.PrayerFocus?)
                        }
                    }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .autocapitalization(.sentences)
                    
                    Text("\(notes.count)/100")
                        .font(.caption)
                        .foregroundColor(notes.count > 100 ? .red : .secondary)
                }
            }
            .navigationTitle("Edit Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(manager.isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateItem()
                    }
                    .disabled(name.isEmpty || notes.count > 100 || manager.isLoading)
                }
            }
        }
    }
    
    private func updateItem() {
        manager.updateItem(
            item,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory,
            relationship: relationship.isEmpty ? nil : relationship.trimmingCharacters(in: .whitespacesAndNewlines),
            prayerFocus: selectedPrayerFocus,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { result in
            switch result {
            case .success:
                dismiss()
                
            case .failure:
                // Error is already handled by manager
                break
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
    }
}
