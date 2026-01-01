//
//  VoiceSelectionView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/16/25.
//  Voice selection with tier-based access
//

import SwiftUI
import AVFoundation

struct VoiceSelectionView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?
    
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
                if isSaving {
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
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func voiceButton(for item: VoiceItem) -> some View {
        Button(action: {
            if !item.isLocked {
                selectVoice(item.index)
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.voice.name)
                        .font(.body)
                        .foregroundColor(item.isLocked ? .gray : .primary)
                    
                    HStack(spacing: 4) {
                        Text(item.voice.language)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let tierBadge = getTierBadge(for: item.index) {
                            Text(tierBadge.text)
                                .font(.caption)
                                .foregroundColor(tierBadge.color)
                        }
                    }
                }
                
                Spacer()
                
                if item.isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .font(.caption)
                } else if item.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(item.isLocked || isSaving)
        .opacity(isSaving ? 0.6 : 1.0)
    }
    
    // MARK: - Computed Properties
    
    private var voiceItems: [VoiceItem] {
        prayerManager.availableVoices.enumerated().map { index, voice in
            VoiceItem(
                index: index,
                voice: voice,
                isLocked: index > maxVoiceIndex,
                isSelected: index == prayerManager.settings.voiceIndex
            )
        }
    }
    
    private var errorMessageBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
    
    private var maxVoiceIndex: Int {
        guard let tier = prayerManager.prayerStats?.tier.lowercased() else {
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
    
    private func getTierBadge(for index: Int) -> (text: String, color: Color)? {
        if index > 2 && index <= 5 {
            return ("• Pro", .blue)
        } else if index > 5 {
            return ("• Warrior", .purple)
        }
        return nil
    }
    
    // MARK: - Actions
    
    private func selectVoice(_ index: Int) {
        isSaving = true
        errorMessage = nil
        
        SettingsAPIService.shared.updateSettings(voiceIndex: index) { result in
            DispatchQueue.main.async {
                isSaving = false
                
                switch result {
                case .success(let user):
                    prayerManager.settings = user.settings
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
                .environmentObject(PrayerManager.shared)
        }
    }
}
