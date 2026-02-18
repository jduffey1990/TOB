//
//  AddPrayerView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/11/25.
//  Refactored to stepper pattern on 02/12/26
//
//  AI-powered prayer builder with stepper UI
//

import SwiftUI

struct AddPrayerView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @EnvironmentObject var prayOnItManager: PrayOnItManager
    @Environment(\.dismiss) var dismiss
    
    // Step management
    @State private var currentStep: Int = 1
    private let totalSteps = 5
    
    // Form state
    @State private var selectedIntentions: Set<String> = []
    @State private var prayerLength: PrayerLength = .standard
    @State private var prayerType: PrayerType = .gratitude
    @State private var tone: PrayerTone = .conversational
    @State private var customContext: String = ""
    @State private var generatedPrayer: String = ""
    @State private var isGenerating: Bool = false
    
    // Error handling states
    @State private var errorMessage: String?
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showUpgradePrompt: Bool = false
    @State private var showIntentionLimitAlert: Bool = false
    
    // Success handling
    @State private var successMessage: String?
    @State private var showSuccessMessage: Bool = false
    
    // View state
    @State private var showReviewScreen: Bool = false
    
    // Computed property for max intentions based on length
    private var maxIntentions: Int {
        switch prayerLength {
        case .brief: return 3
        case .standard: return 5
        case .extended: return Int.max
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if showReviewScreen {
                    // Review and Generate Screen
                    reviewScreen
                } else if !generatedPrayer.isEmpty {
                    // Generated Prayer Screen
                    generatedPrayerScreen
                } else {
                    // Stepper Flow
                    stepperView
                }
            }
            .navigationTitle(navigationTitle)
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
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    alertTitle = ""
                    alertMessage = ""
                }
            } message: {
                Text(alertMessage)
            }
            .alert("Generation Limit Reached", isPresented: $showUpgradePrompt) {
                Button("OK", role: .cancel) {
                    alertMessage = ""
                }
            } message: {
                Text(alertMessage)
            }
            .overlay(
                Group {
                    if showSuccessMessage, let message = successMessage {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(message)
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(10)
                            .padding(.bottom, 50)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut, value: showSuccessMessage)
                    }
                }
            )
        }
    }
    
    // MARK: - Navigation Title
    
    private var navigationTitle: String {
        if !generatedPrayer.isEmpty {
            return "Review Prayer"
        } else if showReviewScreen {
            return "Review & Generate"
        } else {
            return "Create Prayer"
        }
    }
    
    // MARK: - Stepper View
    
    private var stepperView: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            progressIndicator
            
            // Step Content
            ScrollView {
                VStack(spacing: 24) {
                    stepContent
                }
                .padding()
            }
            
            // Navigation Buttons
            navigationButtons
        }
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }
            .padding(.horizontal)
            
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 1:
            lengthStep
        case 2:
            intentionsStep
        case 3:
            typeStep
        case 4:
            toneStep
        case 5:
            contextStep
        default:
            EmptyView()
        }
    }
    
    // MARK: - Step 1: Length
    
    private var lengthStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                icon: "clock",
                title: "How long should your prayer be?",
                description: "Choose the duration that fits your needs"
            )
            
            VStack(spacing: 12) {
                ForEach(PrayerLength.allCases, id: \.self) { length in
                    selectionButton(
                        isSelected: prayerLength == length,
                        title: length.displayName,
                        description: length.description
                    ) {
                        prayerLength = length
                        // Trim selections if changing to more restrictive length
                        if selectedIntentions.count > maxIntentions {
                            let itemsToKeep = Array(selectedIntentions.prefix(maxIntentions))
                            selectedIntentions = Set(itemsToKeep)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Step 2: Intentions
    
    private var intentionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                icon: "person.3",
                title: "Who/What are you praying for?",
                description: "Optional - Select from your 'Pray On It' list or tap Next to skip"
            )
            
            if prayOnItManager.items.isEmpty {
                emptyIntentionsState
            } else {
                intentionsSelector
            }
        }
    }
    
    private var emptyIntentionsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("No Pray On It items yet")
                .font(.headline)
            Text("Add people or intentions to pray for in the Pray On It tab, or skip this step")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var intentionsSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select intentions:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func handleIntentionToggle(itemId: String) {
        if selectedIntentions.contains(itemId) {
            selectedIntentions.remove(itemId)
        } else {
            if selectedIntentions.count >= maxIntentions {
                showIntentionLimitAlert = true
            } else {
                selectedIntentions.insert(itemId)
            }
        }
    }
    
    // MARK: - Step 3: Type
    
    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                icon: "list.bullet",
                title: "What type of prayer?",
                description: "Choose the focus of your prayer"
            )
            
            VStack(spacing: 12) {
                ForEach(PrayerType.allCases, id: \.self) { type in
                    selectionButton(
                        isSelected: prayerType == type,
                        title: type.displayName,
                        description: type.description
                    ) {
                        prayerType = type
                    }
                }
            }
        }
    }
    
    // MARK: - Step 4: Tone
    
    private var toneStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                icon: "waveform",
                title: "What tone?",
                description: "Select the style of language"
            )
            
            VStack(spacing: 12) {
                ForEach(PrayerTone.allCases, id: \.self) { toneOption in
                    selectionButton(
                        isSelected: tone == toneOption,
                        title: toneOption.displayName,
                        description: toneOption.description
                    ) {
                        tone = toneOption
                    }
                }
            }
        }
    }
    
    // MARK: - Step 5: Context
    
    private var contextStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                icon: "text.alignleft",
                title: "Additional context",
                description: "Optional - Add specific details or leave blank"
            )
            
            TextEditor(text: $customContext)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    Group {
                        if customContext.isEmpty {
                            Text("E.g., 'My mother is recovering from surgery' or 'Seeking guidance on a career decision'")
                                .foregroundColor(.gray)
                                .padding(.leading, 16)
                                .padding(.trailing, 16)
                                .padding(.top, 24)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
    
    // MARK: - Review Screen
    
    private var reviewScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review Your Choices")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Check everything looks good before generating")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Review Cards
                reviewCard(
                    icon: "clock",
                    title: "Length",
                    value: prayerLength.displayName
                ) {
                    currentStep = 1
                    showReviewScreen = false
                }
                
                reviewCard(
                    icon: "person.3",
                    title: "Pray On Its",
                    value: selectedIntentions.isEmpty ? "None selected" : "\(selectedIntentions.count) selected"
                ) {
                    currentStep = 2
                    showReviewScreen = false
                }
                
                reviewCard(
                    icon: "list.bullet",
                    title: "Type",
                    value: prayerType.displayName
                ) {
                    currentStep = 3
                    showReviewScreen = false
                }
                
                reviewCard(
                    icon: "waveform",
                    title: "Tone",
                    value: tone.displayName
                ) {
                    currentStep = 4
                    showReviewScreen = false
                }
                
                reviewCard(
                    icon: "text.alignleft",
                    title: "Custom Context",
                    value: customContext.isEmpty ? "None" : customContext
                ) {
                    currentStep = 5
                    showReviewScreen = false
                }
                
                // AI Preview
                aiPreviewSection
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                // Generate Button
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
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Back") {
                    showReviewScreen = false
                    currentStep = totalSteps
                }
            }
        }
    }
    
    private var canGenerate: Bool {
        guard !isGenerating else { return false }
        return !selectedIntentions.isEmpty || !customContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var aiPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI will create:")
                    .font(.headline)
            }
            
            Text(generatePreviewText())
                .font(.body)
                .foregroundColor(.primary)
                .italic()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private func generatePreviewText() -> String {
        guard !selectedIntentions.isEmpty else {
            if !customContext.isEmpty {
                return "A \(prayerLength.displayName.lowercased()), \(tone.displayName.lowercased()) \(prayerType.displayName.lowercased()) prayer based on your custom context"
            }
            return "Select a 'pray on it' item or enter context to preview"
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
        
        return "A \(prayerLength.displayName.lowercased()), \(tone.displayName.lowercased()) \(prayerType.displayName.lowercased()) prayer for \(namesText)"
    }
    
    // MARK: - Generated Prayer Screen
    
    private var generatedPrayerScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("Generated Prayer")
                            .font(.headline)
                    }
                    
                    TextEditor(text: $generatedPrayer)
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Tap to edit prayer before saving")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
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
            .padding()
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                // Back button
                if currentStep > 1 {
                    Button(action: previousStep) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
                
                // Next/Review button
                Button(action: nextStep) {
                    HStack {
                        Text(nextButtonTitle)
                        if currentStep == totalSteps {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private var nextButtonTitle: String {
        if currentStep == 5 {
            return customContext.isEmpty ? "Skip" : "Next"
        } else if currentStep == totalSteps {
            return "Review"
        } else {
            return "Next"
        }
    }
    
    // MARK: - Reusable Components
    
    private func stepHeader(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func selectionButton(isSelected: Bool, title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.primary)
                        .font(.body)
                        .fontWeight(.semibold)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(
                isSelected ?
                Color.blue.opacity(0.15) :
                Color(.systemGray6)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private func reviewCard(icon: String, title: String, value: String, editAction: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: editAction) {
                Text("Edit")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Navigation Actions
    
    private func nextStep() {
        if currentStep < totalSteps {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Go to review
            withAnimation {
                showReviewScreen = true
            }
        }
    }
    
    private func previousStep() {
        if currentStep > 1 {
            withAnimation {
                currentStep -= 1
            }
        }
    }
    
    // MARK: - API Actions
    
    private func generatePrayer() {
        isGenerating = true
        errorMessage = nil
        
        let selectedItems = prayOnItManager.items.filter { selectedIntentions.contains($0.id) }
        
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
        
        prayerManager.postPrompt(requestPayload) { result in
            DispatchQueue.main.async {
                self.isGenerating = false
                
                switch result {
                case .success(let generatedText):
                    print("✅ [AddPrayerView] Prayer generated successfully")
                    self.generatedPrayer = generatedText
                    self.showReviewScreen = false
                    
                case .failure(let error):
                    print("❌ [AddPrayerView] Generation failed: \(error)")
                    self.handleGenerationError(error)
                }
            }
        }
    }
    
    private func savePrayer() {
        let title = "\(prayerType.rawValue) Prayer"
        
        prayerManager.addPrayer(title: title, text: generatedPrayer) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.successMessage = "Prayer saved!"
                    self.showSuccessMessage = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                    
                case .failure(let error):
                    print("❌ [AddPrayerView] Save failed: \(error)")
                    self.handleSaveError(error)
                }
            }
        }
    }
    
    private func startOver() {
        generatedPrayer = ""
        errorMessage = nil
        selectedIntentions.removeAll()
        prayerLength = .standard
        prayerType = .gratitude
        tone = .conversational
        customContext = ""
        currentStep = 1
        showReviewScreen = false
        
        print("🔄 [AddPrayerView] Form reset to defaults")
    }
    
    // MARK: - Error Handling
    
    private func handleGenerationError(_ error: PrayerAPIError) {
        switch error {
        case .unauthorized:
            alertTitle = "Session Expired"
            alertMessage = "Please log in again to continue."
            showAlert = true
            
        case .limitReached(let message):
            alertTitle = "Generation Limit Reached"
            alertMessage = message
            showUpgradePrompt = true
            
        case .networkError(let message):
            errorMessage = "Network error: \(message)"
            
        case .serverError(let message):
            if message.contains("AI service") {
                errorMessage = "AI service temporarily unavailable. Please try again."
            } else {
                errorMessage = message
            }
            
        case .decodingError:
            errorMessage = "Failed to process server response. Please try again."
            
        case .notFound:
            errorMessage = "An unexpected error occurred."
            
        case .unknown:
            errorMessage = "An unexpected error occurred. Please try again."
        }
    }
    
    private func handleSaveError(_ error: PrayerAPIError) {
        switch error {
        case .unauthorized:
            alertTitle = "Session Expired"
            alertMessage = "Please log in again to save your prayer."
            showAlert = true
            
        case .limitReached(let message):
            alertTitle = "Prayer Limit Reached"
            alertMessage = message
            showUpgradePrompt = true
            
        case .networkError(let message):
            alertTitle = "Save Failed"
            alertMessage = "Network error: \(message)"
            showAlert = true
            
        case .serverError(let message):
            alertTitle = "Save Failed"
            alertMessage = message
            showAlert = true
            
        case .decodingError:
            alertTitle = "Save Failed"
            alertMessage = "Failed to process server response."
            showAlert = true
            
        case .notFound:
            alertTitle = "Save Failed"
            alertMessage = "Prayer could not be found."
            showAlert = true
            
        case .unknown:
            alertTitle = "Save Failed"
            alertMessage = "An unexpected error occurred."
            showAlert = true
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
        case .gratitude: return "Giving thanks"
        case .intercession: return "Praying on behalf of others"
        case .petition: return "Requesting help"
        case .confession: return "Acknowledging wrongdoings and seeking forgiveness"
        case .praise: return "Glorify and worship"
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
        case .brief: return 125
        case .standard: return 250
        case .extended: return 450
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
