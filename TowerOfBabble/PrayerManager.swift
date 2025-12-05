import Foundation
import AVFoundation
import Combine

// Model for a single prayer
struct Prayer: Identifiable, Codable {
    let id: UUID
    var title: String
    var text: String
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, text: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
    }
}

class PrayerManager: ObservableObject {
    @Published var prayers: [Prayer] = []
    
    private let synthesizer = AVSpeechSynthesizer()
    private let defaults = UserDefaults.standard
    private let prayersKey = "savedPrayers"
    
    init() {
        loadPrayers()
    }
    
    // Save all prayers
    func savePrayers() {
        if let encoded = try? JSONEncoder().encode(prayers) {
            defaults.set(encoded, forKey: prayersKey)
        }
    }
    
    // Load all prayers
    func loadPrayers() {
        if let data = defaults.data(forKey: prayersKey),
           let decoded = try? JSONDecoder().decode([Prayer].self, from: data) {
            prayers = decoded
        }
    }
    
    // Add a new prayer
    func addPrayer(_ prayer: Prayer) {
        prayers.append(prayer)
        savePrayers()
    }
    
    // Update existing prayer
    func updatePrayer(_ prayer: Prayer) {
        if let index = prayers.firstIndex(where: { $0.id == prayer.id }) {
            prayers[index] = prayer
            savePrayers()
        }
    }
    
    // Delete prayer
    func deletePrayer(_ prayer: Prayer) {
        prayers.removeAll { $0.id == prayer.id }
        savePrayers()
    }
    
    // Speak a prayer
    func speakPrayer(_ prayer: Prayer) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        
        let utterance = AVSpeechUtterance(string: prayer.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
    }
    
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }
}
