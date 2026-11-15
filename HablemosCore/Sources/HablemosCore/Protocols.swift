import Foundation

public struct TranscriptUpdate: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool
    public let level: Float
    /// Other readings of `text` from the recognizer, most likely first.
    public let alternatives: [String]

    public init(text: String, isFinal: Bool, level: Float, alternatives: [String] = []) {
        self.text = text
        self.isFinal = isFinal
        self.level = level
        self.alternatives = alternatives
    }
}

public struct ChatMessage: Sendable, Equatable {
    public enum Role: String, Sendable { case user, tutor }
    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

public protocol SpeechToText: Sendable {
    func startListening(locale: Locale) -> AsyncStream<TranscriptUpdate>
    func stopListening() async
}

public protocol LanguageModel: Sendable {
    func stream(system: String, history: [ChatMessage], user: String) -> AsyncThrowingStream<String, Error>
    func completeJSON(prompt: String, jsonSchema: String) async throws -> String
}

public protocol TextToSpeech: Sendable {
    func speak(_ text: String, locale: Locale, rate: Float) async throws
    func stop() async
}
