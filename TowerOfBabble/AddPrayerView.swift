//
//  AddPrayerView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//
//  AI-powered prayer builder (MOCKED - AI integration coming soon)
//

import SwiftUI

struct AddPrayerView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedIntentions: Set<String> = []
    @State private var prayerType: PrayerType = .gratitude
    @State private var tone: PrayerTone = .conversational
    @State private var customContext: String = ""
    @State private var generatedPrayer: String = ""
    @State private var isGenerating: Bool = false
    
    // Mock "Pray On It" items
    private let mockIntentions = [
        "Mom", "Dad", "Sarah (friend)", "Job Interview",
        "Church Community", "Dad's Health"
    ]
    
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
            
            FlowLayout(spacing: 8) {
                ForEach(mockIntentions, id: \.self) { intention in
                    IntentionChip(
                        title: intention,
                        isSelected: selectedIntentions.contains(intention)
                    ) {
                        if selectedIntentions.contains(intention) {
                            selectedIntentions.remove(intention)
                        } else {
                            selectedIntentions.insert(intention)
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
            .background(isGenerating ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isGenerating || selectedIntentions.isEmpty)
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
                    Label("Save", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: generatePrayer) {
                    Label("Regenerate", systemImage: "arrow.clockwise")
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
        
        // Mock AI generation (simulate network delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let intentions = selectedIntentions.joined(separator: ", ")
            generatedPrayer = """
            Dear Lord,
            
            I come before you with a heart full of \(prayerType.rawValue.lowercased()). I lift up \(intentions) to you today.
            
            \(customContext.isEmpty ? "Grant them Your peace and guidance." : customContext)
            
            May Your will be done in all things. I trust in Your perfect plan and timing.
            
            In Your holy name, Amen.
            """
            isGenerating = false
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

// MARK: - Preview

struct AddPrayerView_Previews: PreviewProvider {
    static var previews: some View {
        AddPrayerView()
            .environmentObject(PrayerManager.shared)
    }
}
