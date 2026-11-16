import AVFoundation
import HablemosCore
import Observation
import SwiftUI

@MainActor
final class AVSpeechSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var current: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, locale: Locale, rate: Float) async throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: locale)
        utterance.rate = rate
        current = ObjectIdentifier(utterance)
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }

    private func utteranceEnded(_ id: ObjectIdentifier) {
        guard id == current else { return }
        current = nil
        finish()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    private static func bestVoice(for locale: Locale) -> AVSpeechSynthesisVoice? {
        let language = locale.identifier(.bcp47)
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
    }
}

struct AVSpeechTextToSpeech: TextToSpeech {
    private let speaker: AVSpeechSpeaker

    @MainActor init() {
        speaker = AVSpeechSpeaker()
    }

    func speak(_ text: String, locale: Locale, rate: Float) async throws {
        try await speaker.speak(text, locale: locale, rate: rate)
    }

    func stop() async {
        await speaker.stop()
    }
}

@MainActor
@Observable
final class SpeechPlayer {
    private(set) var errorMessage: String?
    private let tts: TextToSpeech
    private let locale: Locale
    private var pending: [(text: String, rate: Float)] = []
    private var worker: Task<Void, Never>?
    private var generation = 0

    init(tts: TextToSpeech, locale: Locale = Locale(identifier: "es-MX")) {
        self.tts = tts
        self.locale = locale
    }

    var isSpeaking: Bool { worker != nil }

    func say(_ text: String, rate: Float = 0.45) {
        reset()
        enqueue(text, rate: rate)
    }

    func enqueue(_ text: String, rate: Float = 0.45) {
        pending.append((text, rate))
        guard worker == nil else { return }
        generation += 1
        let current = generation
        worker = Task { [weak self] in
            while let self, current == self.generation, !self.pending.isEmpty {
                let next = self.pending.removeFirst()
                do {
                    try await self.tts.speak(next.text, locale: self.locale, rate: next.rate)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
            if let self, current == self.generation { self.worker = nil }
        }
    }

    func stop() {
        reset()
        Task { await tts.stop() }
    }

    private func reset() {
        generation += 1
        pending.removeAll()
        worker?.cancel()
        worker = nil
    }
}
