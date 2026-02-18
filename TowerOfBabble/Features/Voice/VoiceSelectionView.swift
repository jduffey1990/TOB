//
//  VoiceSelectionView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/16/25.
//
//  VoiceSelectionView.swift
//  TowerOfBabble
//
//  Refactored to use UserSettings and VoiceService
//

import SwiftUI
import AVFoundation

struct VoiceSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var userSettings = UserSettings.shared
    @ObservedObject private var previewManager = VoicePreviewManager.shared 
    @State private var voiceService = VoiceService.shared
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var prayerStats: PrayerStatsResponse?
    
    // MARK: - Helper Structures
    
    private struct VoiceItem: Identifiable {
        let id = UUID()
        let index: Int
        let voice: VoiceOption
        let isLocked: Bool
        let isSelected: Bool
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            ForEach(voiceItems) { item in
                voiceButton(for: item)
            }
        }
        .navigationTitle("Voice Selection")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if isSaving || userSettings.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
        )
        .alert("Error", isPresented: errorMessageBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            loadPrayerStats()
        }
        .onDisappear {
            previewManager.stop()
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func voiceButton(for item: VoiceItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.voice.name)
                    .foregroundColor(item.isLocked ? .gray : .primary)

                HStack(spacing: 4) {
                    Text(item.voice.language)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let tierBadge = voiceService.getTierBadge(for: item.index) {
                        Text(tierBadge.text)
                            .font(.caption)
                            .foregroundColor(tierBadge.color == "blue" ? .blue : .purple)
                    }
                }
            }

            Spacer()

            // ✅ Play button ALWAYS tappable
            if item.voice.provider == "apple" || item.voice.file != nil {
                Button {
                    previewManager.previewVoice(item.voice)
                } label: {
                    Image(systemName:
                        previewManager.currentPlayingVoiceId == item.voice.id && previewManager.isPlaying
                        ? "stop.circle.fill"
                        : "play.circle.fill"
                    )
                    .font(.title3)
                    .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            if item.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .font(.caption)
            } else if item.isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle()) // makes whole row tappable
        .onTapGesture {
            guard !item.isLocked else { return }
            selectVoice(item.index)
        }
        .opacity((isSaving || userSettings.isLoading) ? 0.6 : 1.0)
    }

    
    // MARK: - Computed Properties
    
    private var voiceItems: [VoiceItem] {
        // Change this line:
        voiceService.allVoices.enumerated().map { index, voice in
            VoiceItem(
                index: index,
                voice: voice,
                isLocked: voiceService.isVoiceLocked(voice), // Use the service's helper
                isSelected: index == userSettings.currentVoiceIndex
            )
        }
    }
    
    private var errorMessageBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil || userSettings.errorMessage != nil },
            set: { if !$0 {
                errorMessage = nil
                userSettings.errorMessage = nil
            }}
        )
    }
    
    private var maxVoiceIndex: Int {
        guard let tier = prayerStats?.tier.lowercased() else {
            return 2 // Default to free
        }
        
        switch tier {
        case "free": return 2
        case "pro": return 5
        case "lifetime", "warrior": return 8
        default: return 2
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadPrayerStats() {
        PrayerManager.shared.fetchStats { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stats):
                    prayerStats = stats
                case .failure(let error):
                    print("❌ Failed to load stats: \(error)")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectVoice(_ index: Int) {
        isSaving = true
        errorMessage = nil
        
        userSettings.updateVoiceIndex(index) { result in
            DispatchQueue.main.async {
                isSaving = false
                
                switch result {
                case .success:
                    print("✅ Voice updated to index \(index)")
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    print("❌ Failed to update voice: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

struct VoiceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VoiceSelectionView()
        }
    }
}
