import SwiftUI

struct PrayerEditorView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @Environment(\.dismiss) var dismiss
    
    let prayer: Prayer? // nil if creating new, has value if editing
    
    @State private var title: String = ""
    @State private var text: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title field
                TextField("Prayer Title", text: $title)
                    .font(.headline)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
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
                
                // Buttons
                HStack(spacing: 15) {
                    Button(action: savePrayer) {
                        Label("Save", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
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
                }
            }
            .onAppear {
                if let prayer = prayer {
                    title = prayer.title
                    text = prayer.text
                }
            }
        }
    }
    
    private func savePrayer() {
        guard !title.isEmpty, !text.isEmpty else { return }
        
        if let existingPrayer = prayer {
            // Update existing
            let updated = Prayer(
                id: existingPrayer.id,
                title: title,
                text: text,
                createdAt: existingPrayer.createdAt
            )
            prayerManager.updatePrayer(updated)
        } else {
            // Create new
            let newPrayer = Prayer(title: title, text: text)
            prayerManager.addPrayer(newPrayer)
        }
        
        dismiss()
    }
    
    private func playPrayer() {
        let tempPrayer = Prayer(title: title, text: text)
        prayerManager.speakPrayer(tempPrayer)
    }
}
