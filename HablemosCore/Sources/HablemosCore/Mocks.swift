import Foundation

public final class MockSpeechToText: SpeechToText, @unchecked Sendable {
    private let lock = NSLock()
    private var scripted: [String]

    public init(scripted: [String]) {
        self.scripted = scripted
    }

    public func startListening(locale: Locale) -> AsyncStream<TranscriptUpdate> {
        let text = nextScripted()
        return AsyncStream { continuation in
            let task = Task {
                var spoken = ""
                for word in text.split(separator: " ") {
                    spoken += (spoken.isEmpty ? "" : " ") + word
                    continuation.yield(TranscriptUpdate(text: spoken, isFinal: false, level: .random(in: 0.2...0.9)))
                    try? await Task.sleep(for: .milliseconds(120))
                }
                continuation.yield(TranscriptUpdate(text: text, isFinal: true, level: 0))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func stopListening() async {}

    private func nextScripted() -> String {
        lock.lock()
        defer { lock.unlock() }
        guard !scripted.isEmpty else { return "" }
        return scripted.count > 1 ? scripted.removeFirst() : scripted[0]
    }
}

public final class MockLanguageModel: LanguageModel, @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [String]

    public init(replies: [String]) {
        self.replies = replies
    }

    public func stream(system: String, history: [ChatMessage], user: String) -> AsyncThrowingStream<String, Error> {
        let reply = nextReply()
        return AsyncThrowingStream { continuation in
            let task = Task {
                for word in reply.split(separator: " ", omittingEmptySubsequences: false) {
                    continuation.yield(String(word) + " ")
                    try await Task.sleep(for: .milliseconds(40))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func completeJSON(prompt: String, jsonSchema: String) async throws -> String {
        """
        {"mistakes":[{"original":"es muy rico","corrected":"está muy rico","category":"ser_vs_estar","explanation":"Use estar for how food tastes right now."},{"original":"una café","corrected":"un café","category":"gender_agreement","explanation":"café is masculine."}],"new_words":["para llevar","en efectivo","la cuenta","me alegro"],"estimated_level":"A1"}
        """
    }

    private func nextReply() -> String {
        lock.lock()
        defer { lock.unlock() }
        guard !replies.isEmpty else { return "" }
        return replies.count > 1 ? replies.removeFirst() : replies[0]
    }
}

public final class MockTextToSpeech: TextToSpeech, @unchecked Sendable {
    public init() {}
    public func speak(_ text: String, locale: Locale, rate: Float) async {
        try? await Task.sleep(for: .milliseconds(300))
    }
    public func stop() async {}
}
