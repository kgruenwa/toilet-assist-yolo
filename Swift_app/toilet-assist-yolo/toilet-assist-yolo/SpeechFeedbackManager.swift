//
//  SpeechFeedbackManager.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

import AVFoundation

// Sprache wird nur für Statuswechsel genutzt.
// Also z. B. "Toilette gefunden", aber nicht dauerhaft zur Richtung.
final class SpeechFeedbackManager {
    private let synthesizer = AVSpeechSynthesizer()

    private var lastMessage: String = ""
    private var lastSpeechTime = Date.distantPast

    // Verhindert Audio-Overload.
    private let cooldown: TimeInterval = 3.0

    func speakStatus(_ message: String) {
        let now = Date()

        // Gleiche Nachricht nicht ständig wiederholen.
        guard message != lastMessage || now.timeIntervalSince(lastSpeechTime) > cooldown else {
            return
        }

        // Mindestabstand zwischen zwei Sprachansagen.
        guard now.timeIntervalSince(lastSpeechTime) > cooldown else {
            return
        }

        lastMessage = message
        lastSpeechTime = now

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = 0.50
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }
}
