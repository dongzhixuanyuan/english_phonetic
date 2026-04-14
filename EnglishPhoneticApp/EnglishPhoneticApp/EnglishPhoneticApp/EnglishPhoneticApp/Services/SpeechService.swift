import Foundation
import AVFAudio

class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking = false
    @Published var currentWord: String?
    
    var accent: String = "en-US" {
        didSet { saveSettings() }
    }
    
    var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate {
        didSet { saveSettings() }
    }
    
    private let accentKey = "speech_accent"
    private let rateKey = "speech_rate"
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        loadSettings()
    }
    
    func speak(_ word: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: accent)
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        currentWord = word
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    private func loadSettings() {
        if let savedAccent = UserDefaults.standard.string(forKey: accentKey) {
            accent = savedAccent
        }
        if UserDefaults.standard.object(forKey: rateKey) != nil {
            speechRate = UserDefaults.standard.float(forKey: rateKey)
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(accent, forKey: accentKey)
        UserDefaults.standard.set(speechRate, forKey: rateKey)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        currentWord = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        currentWord = nil
    }
}
