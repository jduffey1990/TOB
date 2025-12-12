//
//  DefaultPrayersView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//
//  Pre-built prayer templates (MOCKED DATA)
//

import SwiftUI

struct DefaultPrayersView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @State private var mockTemplates: [MockPrayerTemplate] = [
        // Christian Traditional
        MockPrayerTemplate(
            title: "The Lord's Prayer",
            text: "Our Father, who art in heaven, hallowed be thy name. Thy kingdom come, thy will be done, on earth as it is in heaven. Give us this day our daily bread, and forgive us our trespasses, as we forgive those who trespass against us. And lead us not into temptation, but deliver us from evil. Amen.",
            category: "Christian Traditional"
        ),
        MockPrayerTemplate(
            title: "Serenity Prayer",
            text: "God, grant me the serenity to accept the things I cannot change, courage to change the things I can, and wisdom to know the difference.",
            category: "Christian Traditional"
        ),
        MockPrayerTemplate(
            title: "Prayer of St. Francis",
            text: "Lord, make me an instrument of your peace. Where there is hatred, let me sow love; where there is injury, pardon; where there is doubt, faith; where there is despair, hope; where there is darkness, light; and where there is sadness, joy.",
            category: "Christian Traditional"
        ),
        
        // Catholic
        MockPrayerTemplate(
            title: "Hail Mary",
            text: "Hail Mary, full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.",
            category: "Catholic"
        ),
        MockPrayerTemplate(
            title: "Guardian Angel Prayer",
            text: "Angel of God, my guardian dear, to whom God's love commits me here, ever this day be at my side, to light and guard, to rule and guide. Amen.",
            category: "Catholic"
        ),
        
        // Celtic/Irish
        MockPrayerTemplate(
            title: "Irish Blessing",
            text: "May the road rise up to meet you. May the wind be always at your back. May the sun shine warm upon your face; the rains fall soft upon your fields and until we meet again, may God hold you in the palm of His hand.",
            category: "Celtic/Irish"
        ),
        
        // Occasion-based
        MockPrayerTemplate(
            title: "Morning Prayer",
            text: "Dear Lord, as I begin this new day, I ask for Your guidance and strength. Help me to face whatever comes with grace and courage. May my actions reflect Your love today. Amen.",
            category: "Occasion-based"
        ),
        MockPrayerTemplate(
            title: "Evening Prayer",
            text: "Gracious God, as this day comes to a close, I thank You for Your blessings and guidance. Forgive me where I have fallen short, and grant me peaceful rest tonight. Amen.",
            category: "Occasion-based"
        ),
        MockPrayerTemplate(
            title: "Bedtime Prayer",
            text: "Now I lay me down to sleep, I pray the Lord my soul to keep. Guard me through the silent night, and wake me with the morning light. Amen.",
            category: "Occasion-based"
        ),
    ]
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showingPrayerDetail: MockPrayerTemplate? = nil
    
    private var categories: [String] {
        Array(Set(mockTemplates.map { $0.category })).sorted()
    }
    
    private var filteredTemplates: [MockPrayerTemplate] {
        var filtered = mockTemplates
        
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
                
                // Mock data banner
                VStack {
                    Spacer()
                    mockDataBanner
                        .padding(.bottom, 80) // Above tab bar
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
    let template: MockPrayerTemplate
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
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: usePrayer) {
                            Label("Use This Prayer", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            prayerManager.speakPrayer(Prayer(
                                title: template.title,
                                text: template.text
                            ))
                        }) {
                            Label(
                                prayerManager.isSpeaking ? "Stop" : "Preview",
                                systemImage: prayerManager.isSpeaking ? "stop.circle" : "play.circle"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(prayerManager.isSpeaking ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
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
        let newPrayer = Prayer(
            title: template.title,
            text: template.text
        )
        prayerManager.addPrayer(newPrayer) { result in
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

// MARK: - Mock Data Model

struct MockPrayerTemplate: Identifiable {
    let id = UUID()
    var title: String
    var text: String
    var category: String
}

// MARK: - Preview

struct DefaultPrayersView_Previews: PreviewProvider {
    static var previews: some View {
        DefaultPrayersView()
            .environmentObject(PrayerManager())
    }
}
