//
//  PrayerEditorView.swift
//  TowerOfBabble
//

import SwiftUI

enum PrayerAudioState {
    case missing
    case building
    case ready(URL)
}

struct PrayerEditorView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    let prayer: Prayer? // nil if creating new, has value if editing
    
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSaving: Bool = false
    @State private var showingImmutableInfo: Bool = false
    
    private var isImmutable: Bool {
        prayer != nil
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // MARK: - Title
                TextField("Prayer Title", text: $title)
                    .font(.headline)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .disabled(isSaving)
                
                // MARK: - Prayer Text
                ZStack {
                    ScrollView {
                        TextEditor(text: $text)
                            .frame(minHeight: 300)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .disabled(isSaving || isImmutable)
                    }

                    // Tap catcher when immutable
                    if isImmutable {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingImmutableInfo = true
                            }
                    }
                }

                
                if isImmutable {
                    Text("To preserve saved MP3s, prayers that have already been generated for the selected voice cannot be edited.  Titles remain editable.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 4)
                }

                
                // MARK: - Bottom Buttons (ONLY when creating new)
                if prayer == nil {
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
                }
                
                // MARK: - Audio Button (ONLY when editing)
                if prayer != nil {
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
                
                Spacer()
            }
            .padding()
            .navigationTitle(prayer == nil ? "New Prayer" : "Prayer")
            .navigationBarTitleDisplayMode(.inline)
            
            // MARK: - Toolbar
            .toolbar {
                
                // Cancel only for new
                if prayer == nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .disabled(isSaving)
                    }
                }
                
                // Save in NavBar only when editing
                if prayer != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            savePrayer()
                        }
                        .disabled(isSaving || title.isEmpty)
                    }
                }
            }
            
            .task(id: prayer?.id) {
                fetchAudioState()
            }
            
            .onAppear {
                if let prayer = prayer {
                    title = prayer.title
                    text = prayer.text
                    fetchAudioState()
                }
            }
            
            .onDisappear {
                audioPlayer.stopSpeaking()
            }
            
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                Text(errorMessage)
            }
            .alert("Prayer Text Locked", isPresented: $showingImmutableInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(
                    "To preserve saved MP3s, prayers that have already been generated for the selected voice cannot be edited."
                )
            }

        }
    }
}

// MARK: - Audio Button UI

extension PrayerEditorView {
    
    private var actionButtonLabel: some View {
        let voice = VoiceService.shared.getCurrentVoice()
        let isAppleTTS = voice?.provider == "apple"
        
        if isAppleTTS {
            return AnyView(
                Label(
                    audioPlayer.isSpeaking ? "Stop" : "Play",
                    systemImage: audioPlayer.isSpeaking ? "stop.circle" : "play.circle"
                )
            )
        } else {
            switch audioPlayer.audioState {
            case .missing:
                return AnyView(Label("Generate Audio", systemImage: "waveform"))
                
            case .building:
                return AnyView(Label("Building Audio…", systemImage: "hourglass"))
                
            case .ready:
                return AnyView(
                    Label(
                        audioPlayer.isSpeaking ? "Stop" : "Play",
                        systemImage: audioPlayer.isSpeaking ? "stop.circle" : "play.circle"
                    )
                )
            }
        }
    }
    
    private var isActionButtonDisabled: Bool {
        if case .building = audioPlayer.audioState { return true }
        return isSaving
    }
    
    private var actionButtonColor: Color {
        let voice = VoiceService.shared.getCurrentVoice()
        let isAppleTTS = voice?.provider == "apple"
        
        if isAppleTTS {
            return audioPlayer.isSpeaking ? .red : .green
        } else {
            switch audioPlayer.audioState {
            case .missing: return .blue
            case .building: return .gray
            case .ready: return audioPlayer.isSpeaking ? .red : .green
            }
        }
    }
}

// MARK: - Actions

extension PrayerEditorView {
    
    private func savePrayer() {
        guard !title.isEmpty else { return }
        
        isSaving = true
        
        if let existingPrayer = prayer {
            var updatedPrayer = existingPrayer
            updatedPrayer.title = title
            
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
    
    private func fetchAudioState() {
        guard let prayer = prayer else { return }
        guard let voice = VoiceService.shared.getCurrentVoice() else { return }
        
        audioPlayer.checkAudioState(prayerId: prayer.id, voiceId: voice.id) { _ in }
    }
    
    private func handleActionButton() {
        guard let prayer = prayer else { return }
        
        if audioPlayer.isSpeaking {
            audioPlayer.stopSpeaking()
            return
        }
        
        guard let voice = VoiceService.shared.getCurrentVoice() else { return }
        
        switch audioPlayer.audioState {
        case .missing, .building:
            audioPlayer.playPrayer(prayer, voice: voice)
            
        case .ready(let url):
            audioPlayer.playRemoteAudio(url)
        }
    }
}
