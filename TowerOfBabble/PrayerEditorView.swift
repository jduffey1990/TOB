//
//  PrayerEditorView.swift
//  TowerOfBabble
//
//  Updated with better error handling and API integration
//

import SwiftUI

enum PrayerAudioState {
    case missing
    case building
    case ready(URL)
}

struct PrayerEditorView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @Environment(\.dismiss) var dismiss
    
    let prayer: Prayer? // nil if creating new, has value if editing
    
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSaving: Bool = false
    @State private var audioState: PrayerAudioState = .missing
    @State private var pollingTimer: Timer?
    private var isImmutable: Bool {
        prayer != nil
    }

    
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
                                .stroke(isImmutable ? Color.gray : Color.blue, lineWidth: 1)
                        )
                    .disabled(isSaving || isImmutable)
                
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
                    
                    Button(action: handleActionButton) {
                        actionButtonLabel
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(actionButtonColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isActionButtonDisabled)

                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle(prayer == nil ? "New Prayer" : "Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if prayer == nil {  // Only show Cancel when creating new
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .onAppear {
                if let prayer = prayer {
                    title = prayer.title
                    text = prayer.text
                    fetchAudioState()
                }
            }
            .onDisappear {
                pollingTimer?.invalidate()
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
        
    private var actionButtonLabel: some View {
        switch audioState {
        case .missing:
            return AnyView(Label("Generate Audio", systemImage: "waveform"))
        case .building:
            return AnyView(Label("Building Audio…", systemImage: "hourglass"))
        case .ready:
            return AnyView(
                Label(
                    prayerManager.isSpeaking ? "Stop" : "Play",
                    systemImage: prayerManager.isSpeaking ? "stop.circle" : "play.circle"
                )
            )
        }
    }
    private var isActionButtonDisabled: Bool {
        if case .building = audioState { return true }
        return isSaving
    }

    private var actionButtonColor: Color {
        switch audioState {
        case .missing: return .blue
        case .building: return .gray
        case .ready: return prayerManager.isSpeaking ? .red : .green
        }
    }

    
    private func savePrayer() {
        guard !title.isEmpty, !text.isEmpty else { return }
        
        isSaving = true
        
        if let existingPrayer = prayer {
            // Update existing - modify the copy
            var updatedPrayer = existingPrayer
            updatedPrayer.title = title
            updatedPrayer.text = text
            
            prayerManager.updatePrayer(updatedPrayer) { result in
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
        } else {
            // Create new - use title and text only
            prayerManager.addPrayer(title: title, text: text) { result in
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
        if let existingPrayer = prayer {
            // Editing existing prayer - play the saved one (records playback)
            prayerManager.speakPrayer(existingPrayer)
        } else {
            // New prayer not yet saved - just preview the text (no playback recording)
            prayerManager.speakText(text)
        }
    }
        
    private func fetchAudioState() {
        guard let prayer = prayer else { return }

        prayerManager.fetchAudioState(prayerId: prayer.id) { state in
            DispatchQueue.main.async {
                audioState = state

                if case .building = state {
                    startPolling()
                }
            }
        }
    }
    private func startPolling() {
        if pollingTimer != nil { return }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            fetchAudioState()
        }
    }
    private func handleActionButton() {
        guard let prayer = prayer else { return }

        switch audioState {
        case .missing:
            prayerManager.requestAudioGeneration(prayerId: prayer.id)
            audioState = .building
            startPolling()

        case .building:
            return

        case .ready(let url):
            if prayerManager.isSpeaking {
                prayerManager.stopSpeaking()
            } else {
                prayerManager.playRemoteAudio(url)
            }
        }
    }




}
