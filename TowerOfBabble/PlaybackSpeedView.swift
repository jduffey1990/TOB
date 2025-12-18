//
//  PlaybackSpeedView.swift
//  TowerOfBabble
//
//  Created by Jordan Duffey on 12/16/25.
//
//  Playback speed adjustment
//

import SwiftUI

struct PlaybackSpeedView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @Environment(\.dismiss) var dismiss
    @State private var localRate: Double
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasChanges = false
    
    init() {
        // Initialize with current setting
        _localRate = State(initialValue: 0.5)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Current Speed Display
            VStack(spacing: 8) {
                Text("Playback Speed")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(formatRate(localRate))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.top, 32)
            
            // Slider
            VStack(spacing: 16) {
                Slider(value: $localRate, in: 0.3...0.7, step: 0.1)
                    .accentColor(.blue)
                    .disabled(isSaving)
                    .onChange(of: localRate) { _ in
                        hasChanges = true
                    }
                
                HStack {
                    Text("Slower")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Faster")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            // Speed Presets
            VStack(spacing: 12) {
                Text("Quick Select")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    SpeedPresetButton(speed: 0.3, label: "Slow", currentSpeed: $localRate)
                    SpeedPresetButton(speed: 0.5, label: "Normal", currentSpeed: $localRate)
                    SpeedPresetButton(speed: 0.7, label: "Fast", currentSpeed: $localRate)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Save Button
            Button(action: saveSpeed) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Saving...")
                    } else {
                        Image(systemName: "checkmark")
                        Text("Save")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(hasChanges && !isSaving ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!hasChanges || isSaving)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("Playback Speed")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            localRate = prayerManager.settings.playbackRate
        }
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
    
    // MARK: - Helper Methods
    
    private func formatRate(_ rate: Double) -> String {
        switch rate {
        case 0.3: return "Slow"
        case 0.4: return "Slower"
        case 0.5: return "Normal"
        case 0.6: return "Faster"
        case 0.7: return "Fast"
        default: return String(format: "%.1fx", rate)
        }
    }
    
    private func saveSpeed() {
        isSaving = true
        errorMessage = nil
        
        SettingsAPIService.shared.updateSettings(playbackRate: localRate) { result in
            DispatchQueue.main.async {
                isSaving = false
                
                switch result {
                case .success(let user):
                    prayerManager.settings = user.settings
                    hasChanges = false
                    print("✅ Playback speed updated to \(localRate)")
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    print("❌ Failed to update speed: \(error)")
                }
            }
        }
    }
}

// MARK: - Speed Preset Button

struct SpeedPresetButton: View {
    let speed: Double
    let label: String
    @Binding var currentSpeed: Double
    
    var isSelected: Bool {
        abs(currentSpeed - speed) < 0.01
    }
    
    var body: some View {
        Button(action: {
            currentSpeed = speed
        }) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(10)
        }
    }
}

// MARK: - Preview

struct PlaybackSpeedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PlaybackSpeedView()
                .environmentObject(PrayerManager.shared)
        }
    }
}
