//
//  PrayerEditorView.swift
//  TowerOfBabble
//
//  Updated with better error handling and API integration
//

import SwiftUI

struct PrayerEditorView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @Environment(\.dismiss) var dismiss
    
    let prayer: Prayer? // nil if creating new, has value if editing
    
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title field
                TextField("Prayer Title", text: $title)
                    .font(.headline)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .disabled(isSaving)
                
                // Text editor
                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .disabled(isSaving)
                
                // Buttons
                HStack(spacing: 15) {
                    Button(action: savePrayer) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.6))
                                .cornerRadius(10)
                        } else {
                            Label("Save", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isSaving || title.isEmpty || text.isEmpty)
                    
                    Button(action: playPrayer) {
                        Label(
                            prayerManager.isSpeaking ? "Stop" : "Play",
                            systemImage: prayerManager.isSpeaking ? "stop.circle" : "play.circle"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(prayerManager.isSpeaking ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(text.isEmpty || isSaving)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle(prayer == nil ? "New Prayer" : "Edit Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                if let prayer = prayer {
                    title = prayer.title
                    text = prayer.text
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func savePrayer() {
        guard !title.isEmpty, !text.isEmpty else { return }
        
        isSaving = true
        
        if let existingPrayer = prayer {
            // Update existing
            let updated = Prayer(
                id: existingPrayer.id,
                title: title,
                text: text,
                createdAt: existingPrayer.createdAt
            )
            prayerManager.updatePrayer(updated)
            
            // Wait a moment for the API call to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                if prayerManager.errorMessage == nil {
                    dismiss()
                } else {
                    errorMessage = prayerManager.errorMessage ?? "Failed to save prayer"
                    showingError = true
                    prayerManager.errorMessage = nil
                }
            }
        } else {
            // Create new
            let newPrayer = Prayer(title: title, text: text)
            prayerManager.addPrayer(newPrayer) { result in
                DispatchQueue.main.async {
                    isSaving = false
                    
                    switch result {
                    case .success:
                        dismiss()
                        
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }
    
    private func playPrayer() {
        let tempPrayer = Prayer(title: title, text: text)
        prayerManager.speakPrayer(tempPrayer)
    }
}
