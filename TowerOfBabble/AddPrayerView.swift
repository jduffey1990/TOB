//
//  AddPrayerView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//  Updated by Claude on 01/06/26
//
//  AI-powered prayer builder with intention limits
//

import SwiftUI

struct AddPrayerView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @EnvironmentObject var prayOnItManager: PrayOnItManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedIntentions: Set<String> = []
    @State private var prayerLength: PrayerLength = .standard
    @State private var prayerType: PrayerType = .gratitude
    @State private var tone: PrayerTone = .conversational
    @State private var customContext: String = ""
    @State private var generatedPrayer: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    @State private var showIntentionLimitAlert: Bool = false
    
    // Computed property for max intentions based on length
    private var maxIntentions: Int {
        switch prayerLength {
        case .brief: return 3
        case .standard: return 5
        case .extended: return Int.max // Unlimited
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Step 1: Prayer Length
                    stepSection(
                        number: 1,
                        title: "How long should your prayer be?",
                        icon: "clock"
                    ) {
                        lengthPicker
                    }
                    
                    // Step 2: Select Intentions
                    stepSection(
                        number: 2,
                        title: "Who/What are you praying for?",
                        icon: "person.3"
                    ) {
                        intentionsSelector
                    }
                    
                    // Step 3: Prayer Type
                    stepSection(
                        number: 3,
                        title: "What type of prayer?",
                        icon: "list.bullet"
                    ) {
                        prayerTypePicker
                    }
                    
                    // Step 4: Tone
                    stepSection(
                        number: 4,
                        title: "What tone?",
                        icon: "waveform"
                    ) {
                        tonePicker
                    }
                    
                    // Step 5: Custom Context
                    stepSection(
                        number: 5,
                        title: "Additional context (optional)",
                        icon: "text.alignleft"
                    ) {
                        customContextField
                    }
                    
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
            .alert("Intention Limit Reached", isPresented: $showIntentionLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("To use more than \(maxIntentions) 'Pray On Its', please increase to \(prayerLength == .brief ? "Standard or Extended" : "Extended") length.")
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
    
    private var lengthPicker: some View {
        VStack(spacing: 8) {
            ForEach(PrayerLength.allCases, id: \.self) { length in
                Button(action: {
                    prayerLength = length
                    // If changing to a more restrictive length, trim selections
                    if selectedIntentions.count > maxIntentions {
                        // Keep only the first N selections
                        let itemsToKeep = Array(selectedIntentions.prefix(maxIntentions))
                        selectedIntentions = Set(itemsToKeep)
                    }
                }) {
                    HStack {
                        Image(systemName: prayerLength == length ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(length.displayName)
                                .foregroundColor(.primary)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(length.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        prayerLength == length ?
                        Color.blue.opacity(0.1) :
                        Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var intentionsSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select from your 'Pray On It' list:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show count and limit
                if prayerLength != .extended {
                    Text("\(selectedIntentions.count)/\(maxIntentions)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedIntentions.count >= maxIntentions ? .orange : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            selectedIntentions.count >= maxIntentions ?
                            Color.orange.opacity(0.2) :
                            Color.blue.opacity(0.1)
                        )
                        .cornerRadius(8)
                } else {
                    Text("\(selectedIntentions.count) selected")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
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
                            handleIntentionToggle(itemId: item.id)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func handleIntentionToggle(itemId: String) {
        if selectedIntentions.contains(itemId) {
            // Always allow deselection
            selectedIntentions.remove(itemId)
        } else {
            // Check if we can add more
            if selectedIntentions.count >= maxIntentions {
                showIntentionLimitAlert = true
            } else {
                selectedIntentions.insert(itemId)
            }
        }
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .foregroundColor(.primary)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(toneOption.displayName)
                                .foregroundColor(.primary)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(toneOption.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
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
        let toneText = tone.displayName.lowercased()
        let typeText = prayerType.displayName.lowercased()
        
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
            
            // Make the text editable with TextEditor
            TextEditor(text: $generatedPrayer)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .frame(minHeight: 150) // Ensures adequate editing space
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            
            // Optional: Add a hint that it's editable
            Text("Tap to edit prayer before saving")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
            
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
    
    // MARK: - Actions
    
    private func generatePrayer() {
        isGenerating = true
        
        // Get full Pray On It item objects
        let selectedItems = prayOnItManager.items.filter { selectedIntentions.contains($0.id) }
        
        // Build request payload - NOTE: expansiveness removed
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
            "customContext": customContext.isEmpty ? NSNull() : customContext
        ]
        
        print("📤 [AddPrayerView] Sending prompt generation request")
        print("   Prayer Type: \(prayerType.rawValue)")
        print("   Tone: \(tone.rawValue)")
        print("   Length: \(prayerLength.rawValue)")
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
        prayerLength = .standard
        prayerType = .gratitude
        tone = .conversational
        customContext = ""
        
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
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .gratitude: return "Giving thanks to God"
        case .intercession: return "Praying on behalf of others"
        case .petition: return "Requesting God's help"
        case .confession: return "Acknowledging sins and seeking forgiveness"
        case .praise: return "Glorifying and worshiping God"
        }
    }
}

enum PrayerTone: String, CaseIterable {
    case formal = "Formal"
    case conversational = "Conversational"
    case contemplative = "Contemplative"
    case joyful = "Joyful"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .formal: return "Traditional and reverent language"
        case .conversational: return "Natural, everyday language"
        case .contemplative: return "Reflective and meditative"
        case .joyful: return "Celebratory and uplifting"
        }
    }
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
    
    var description: String {
        switch self {
        case .brief: return "Up to 3 pray-on-its"
        case .standard: return "Up to 5 pray-on-its"
        case .extended: return "Unlimited pray-on-its"
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

// MARK: - Preview

struct AddPrayerView_Previews: PreviewProvider {
    static var previews: some View {
        AddPrayerView()
            .environmentObject(PrayerManager.shared)
            .environmentObject(PrayOnItManager.shared)
    }
}
