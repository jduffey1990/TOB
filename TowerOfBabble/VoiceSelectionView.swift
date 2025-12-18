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
    
    var body: some View {
        List {
            ForEach(Array(prayerManager.getAvailableVoices().enumerated()), id: \.offset) { index, voice in
                let isLocked = index > maxVoiceIndex
                let isSelected = index == prayerManager.settings.voiceIndex
                
                Button(action: {
                    if !isLocked {
                        selectVoice(index)
                    } else {
                        // Show upgrade prompt
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(voice.name)
                                .font(.body)
                                .foregroundColor(isLocked ? .gray : .primary)
                            
                            HStack(spacing: 4) {
                                Text(voice.language)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if index > 2 && index <= 5 {
                                    Text("• Pro")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                } else if index > 5 {
                                    Text("• Warrior")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        } else if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(isLocked || isSaving)
                .opacity(isSaving ? 0.6 : 1.0)
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
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var maxVoiceIndex: Int {
        // Based on user's tier
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
