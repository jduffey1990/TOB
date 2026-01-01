//
//  AddPrayerView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//  Updated by Claude on 12/18/25
//
//  AI-powered prayer builder with advanced options
//

import SwiftUI

struct AddPrayerView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @EnvironmentObject var prayOnItManager: PrayOnItManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedIntentions: Set<String> = []
    @State private var prayerType: PrayerType = .gratitude
    @State private var tone: PrayerTone = .conversational
    @State private var prayerLength: PrayerLength = .standard
    @State private var expansiveness: PrayerExpansiveness = .balanced
    @State private var customContext: String = ""
    @State private var generatedPrayer: String = ""
    @State private var isGenerating: Bool = false
    @State private var showAdvancedOptions: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Step 1: Select Intentions
                    stepSection(
                        number: 1,
                        title: "Who/What are you praying for?",
                        icon: "person.3"
                    ) {
                        intentionsSelector
                    }
                    
                    // Step 2: Prayer Type
                    stepSection(
                        number: 2,
                        title: "What type of prayer?",
                        icon: "list.bullet"
                    ) {
                        prayerTypePicker
                    }
                    
                    // Step 3: Tone
                    stepSection(
                        number: 3,
                        title: "What tone?",
                        icon: "waveform"
                    ) {
                        tonePicker
                    }
                    
                    // Step 4: Custom Context
                    stepSection(
                        number: 4,
                        title: "Additional context (optional)",
                        icon: "text.alignleft"
                    ) {
                        customContextField
                    }
                    
                    // Advanced Options (Collapsible)
                    advancedOptionsSection
                    
                    // AI Preview Text
                    aiPreviewText
                    
                    // Generate Button
                    generateButton
                    
                    // Generated Prayer (if any)
                    if !generatedPrayer.isEmpty {
                        generatedPrayerSection
                    }
                    
                    // Mock data notice
                    mockDataNotice
                }
                .padding()
            }
            .navigationTitle("Create Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private func stepSection<Content: View>(
        number: Int,
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Step number circle
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    Text("\(number)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                // Icon and title
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                }
            }
            
            content()
        }
    }
    
    private var intentionsSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select from your 'Pray On It' list:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if prayOnItManager.items.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("No Pray On It items yet")
                        .font(.headline)
                    Text("Add people or intentions to pray for in the Pray On It tab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(prayOnItManager.items) { item in
                        IntentionChip(
                            title: item.name,
                            isSelected: selectedIntentions.contains(item.id)
                        ) {
                            if selectedIntentions.contains(item.id) {
                                selectedIntentions.remove(item.id)
                            } else {
                                selectedIntentions.insert(item.id)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var prayerTypePicker: some View {
        VStack(spacing: 8) {
            ForEach(PrayerType.allCases, id: \.self) { type in
                Button(action: {
                    prayerType = type
                }) {
                    HStack {
                        Image(systemName: prayerType == type ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)
                        Text(type.rawValue)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(
                        prayerType == type ?
                        Color.blue.opacity(0.1) :
                        Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var tonePicker: some View {
        VStack(spacing: 8) {
            ForEach(PrayerTone.allCases, id: \.self) { toneOption in
                Button(action: {
                    tone = toneOption
                }) {
                    HStack {
                        Image(systemName: tone == toneOption ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)
                        Text(toneOption.rawValue)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(
                        tone == toneOption ?
                        Color.blue.opacity(0.1) :
                        Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var customContextField: some View {
        TextEditor(text: $customContext)
            .frame(minHeight: 100)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                Group {
                    if customContext.isEmpty {
                        Text("Add any specific details...")
                            .foregroundColor(.gray)
                            .padding(.leading, 12)
                            .padding(.top, 16)
                    }
                },
                alignment: .topLeading
            )
    }
    
    // MARK: - Advanced Options Section
    
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Toggle button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showAdvancedOptions.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.blue)
                    Text("Advanced Options")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Expandable content
            if showAdvancedOptions {
                VStack(alignment: .leading, spacing: 20) {
                    // Length picker
                    lengthPicker
                    
                    Divider()
                    
                    // Expansiveness picker
                    expansivenessPicker
                    
                    // Reset button
                    resetAdvancedButton
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private var lengthPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Prayer Length")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 8) {
                ForEach(PrayerLength.allCases, id: \.self) { length in
                    Button(action: {
                        prayerLength = length
                    }) {
                        HStack {
                            Image(systemName: prayerLength == length ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(length.displayName)
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            prayerLength == length ?
                            Color.blue.opacity(0.1) :
                            Color.white
                        )
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var expansivenessPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.blue)
                Text("Writing Style")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 8) {
                ForEach(PrayerExpansiveness.allCases, id: \.self) { style in
                    Button(action: {
                        expansiveness = style
                    }) {
                        HStack {
                            Image(systemName: expansiveness == style ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.displayName)
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            expansiveness == style ?
                            Color.blue.opacity(0.1) :
                            Color.white
                        )
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var resetAdvancedButton: some View {
        Button(action: {
            withAnimation {
                prayerLength = .standard
                expansiveness = .balanced
            }
        }) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset to Defaults")
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - AI Preview Text
    
    private var aiPreviewText: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                    .font(.caption)
                Text("AI will create:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(generatePreviewText())
                .font(.subheadline)
                .foregroundColor(.primary)
                .italic()
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func generatePreviewText() -> String {
        guard !selectedIntentions.isEmpty else {
            return "Select a 'pray on it' item or enter a prompt to get started"
        }
        
        let selectedItems = prayOnItManager.items.filter { selectedIntentions.contains($0.id) }
        let names = selectedItems.map { $0.name }
        
        let namesText: String
        if names.count == 1 {
            namesText = names[0]
        } else if names.count == 2 {
            namesText = "\(names[0]) and \(names[1])"
        } else {
            let firstTwo = names.prefix(2).joined(separator: ", ")
            namesText = "\(firstTwo), and \(names.count - 2) other\(names.count - 2 == 1 ? "" : "s")"
        }
        
        let lengthText = prayerLength.displayName.lowercased()
        let toneText = tone.rawValue.lowercased()
        let typeText = prayerType.rawValue.lowercased()
        
        return "A \(lengthText), \(toneText) \(typeText) prayer for \(namesText)"
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        Button(action: generatePrayer) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Generating...")
                } else {
                    Image(systemName: "sparkles")
                    Text("Generate Prayer with AI")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canGenerate ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canGenerate)

    }
    
    private var canGenerate: Bool {
            guard !isGenerating else { return false }
            // Can generate if either has selected intentions OR has custom context
            return !selectedIntentions.isEmpty || !customContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    
    private var generatedPrayerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("Generated Prayer")
                    .font(.headline)
            }
            
            Text(generatedPrayer)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            HStack(spacing: 12) {
                Button(action: savePrayer) {
                    Label("Save Prayer", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: startOver) {
                    Label("Start Over", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var mockDataNotice: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("AI Integration Coming Soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Currently using mock prayer generation. OpenAI integration will be added in Phase 3.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func estimatedReadingTime(for length: PrayerLength) -> String {
        // Average speaking rate: ~150 words per minute at 1x speed
        let wordsPerMinute = 150.0 
        
        let estimatedWords = Double(length.estimatedWordCount)
        let minutes = estimatedWords / wordsPerMinute
        
        if minutes < 1.0 {
            let seconds = Int(minutes * 60)
            return "\(seconds) sec"
        } else if minutes < 2.0 {
            return "1 min"
        } else {
            let roundedMinutes = Int(round(minutes))
            return "\(roundedMinutes) min"
        }
    }
    
    // MARK: - Actions
    
    private func generatePrayer() {
        isGenerating = true
        
        // Get full Pray On It item objects
        let selectedItems = prayOnItManager.items.filter { selectedIntentions.contains($0.id) }
        
        // Build request payload
        let requestPayload: [String: Any] = [
            "prayOnItItems": selectedItems.map { item in
                [
                    "id": item.id,
                    "name": item.name,
                    "category": item.category.rawValue,
                    "relationship": item.relationship as Any,
                    "prayerFocus": item.prayerFocus?.rawValue as Any,
                    "notes": item.notes as Any
                ]
            },
            "prayerType": prayerType.rawValue.lowercased(),
            "tone": tone.rawValue.lowercased(),
            "length": prayerLength.rawValue.lowercased(),
            "expansiveness": expansiveness.rawValue.lowercased(),
            "customContext": customContext.isEmpty ? NSNull() : customContext
        ]
        
        print("📤 [AddPrayerView] Sending prompt generation request")
        print("   Prayer Type: \(prayerType.rawValue)")
        print("   Tone: \(tone.rawValue)")
        print("   Length: \(prayerLength.rawValue)")
        print("   Expansiveness: \(expansiveness.rawValue)")
        print("   Selected Items: \(selectedItems.map { $0.name }.joined(separator: ", "))")
        
        // Call PrayerManager to post prompt
        prayerManager.postPrompt(requestPayload) { result in
            DispatchQueue.main.async {
                self.isGenerating = false
                
                switch result {
                case .success(let generatedText):
                    print("✅ [AddPrayerView] Prayer generated successfully")
                    self.generatedPrayer = generatedText
                    
                case .failure(let error):
                    print("❌ [AddPrayerView] Generation failed: \(error)")
                    // Error already handled by prayerManager, just show to user
                    self.errorMessage = "Failed to generate prayer. Please try again."
                }
            }
        }
    }
    
    private func savePrayer() {
        let title = "\(prayerType.rawValue) Prayer"
        
        prayerManager.addPrayer(title: title, text: generatedPrayer) { result in
            switch result {
            case .success:
                dismiss()
            case .failure:
                // Error handled by prayerManager
                break
            }
        }
    }
    
    private func startOver() {
        // Clear generated prayer
        generatedPrayer = ""
        errorMessage = nil
        
        // Reset to defaults
        selectedIntentions.removeAll()
        prayerType = .gratitude
        tone = .conversational
        prayerLength = .standard
        expansiveness = .balanced
        customContext = ""
        showAdvancedOptions = false
        
        print("🔄 [AddPrayerView] Form reset to defaults")
    }
}

// MARK: - Supporting Views

struct IntentionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// Simple flow layout for wrapping chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: ProposedViewSize(result.frames[index].size))
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Enums

enum PrayerType: String, CaseIterable {
    case gratitude = "Gratitude"
    case intercession = "Intercession"
    case petition = "Petition"
    case confession = "Confession"
    case praise = "Praise"
}

enum PrayerTone: String, CaseIterable {
    case formal = "Formal"
    case conversational = "Conversational"
    case contemplative = "Contemplative"
    case joyful = "Joyful"
}

enum PrayerLength: String, CaseIterable {
    case brief = "brief"
    case standard = "standard"
    case extended = "extended"
    
    var displayName: String {
        switch self {
        case .brief: return "Brief (1-2 min)"
        case .standard: return "Standard (3-4 min)"
        case .extended: return "Extended (5+ min)"
        }
    }
    
    var estimatedWordCount: Int {
        switch self {
        case .brief: return 125        // ~125 words ≈ 1 min at normal speed
        case .standard: return 250     // ~250 words ≈ 2 min at normal speed
        case .extended: return 450     // ~450 words ≈ 3 min at normal speed
        }
    }
}

enum PrayerExpansiveness: String, CaseIterable {
    case concise = "concise"
    case balanced = "balanced"
    case expansive = "expansive"
    
    var displayName: String {
        switch self {
        case .concise: return "Concise & Direct"
        case .balanced: return "Balanced"
        case .expansive: return "Expansive & Reflective"
        }
    }
    
    var description: String {
        switch self {
        case .concise: return "Short, focused sentences"
        case .balanced: return "Mix of detail and brevity"
        case .expansive: return "Poetic and reflective"
        }
    }
}

// MARK: - Preview

struct AddPrayerView_Previews: PreviewProvider {
    static var previews: some View {
        AddPrayerView()
            .environmentObject(PrayerManager.shared)
            .environmentObject(PrayOnItManager.shared)
    }
}
