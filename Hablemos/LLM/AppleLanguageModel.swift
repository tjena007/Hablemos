import Foundation
import FoundationModels
import HablemosCore

/// Lucía backed by Apple's on-device Foundation Models instead of Gemma. Experimental: lets the two be compared.
struct AppleLanguageModel: HablemosCore.LanguageModel {
    struct Unavailable: Error, CustomStringConvertible {
        let description: String
    }

    static func checkAvailable() throws {
        guard case .unavailable(let reason) = SystemLanguageModel.default.availability else { return }
        let message = switch reason {
        case .deviceNotEligible: "this iPhone can't run Apple Intelligence"
        case .appleIntelligenceNotEnabled: "turn on Apple Intelligence in Settings › Apple Intelligence & Siri"
        case .modelNotReady: "iOS is still downloading Apple's model; try again later"
        @unknown default: "Apple's model is unavailable (\(reason))"
        }
        throw Unavailable(description: message)
    }

    func stream(system: String, history: [ChatMessage], user: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(transcript: Self.transcript(system: system, history: history))
                    var sent = ""
                    // Each snapshot is the whole reply so far; pass on only what's new.
                    for try await snapshot in session.streamResponse(to: user, options: GenerationOptions(temperature: 0.7)) {
                        let text = snapshot.content
                        guard text.hasPrefix(sent) else { continue }
                        continuation.yield(String(text.dropFirst(sent.count)))
                        sent = text
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func completeJSON(prompt: String, jsonSchema: String) async throws -> String {
        let response = try await LanguageModelSession().respond(to: "\(prompt)\n\nReply with only JSON matching this JSON schema:\n\(jsonSchema)")
        return response.content
    }

    private static func transcript(system: String, history: [ChatMessage]) -> Transcript {
        func text(_ string: String) -> [Transcript.Segment] { [.text(Transcript.TextSegment(content: string))] }
        var entries: [Transcript.Entry] = system.isEmpty ? [] : [.instructions(Transcript.Instructions(segments: text(system), toolDefinitions: []))]
        for message in history {
            entries.append(message.role == .user
                ? .prompt(Transcript.Prompt(segments: text(message.text)))
                : .response(Transcript.Response(assetIDs: [], segments: text(message.text))))
        }
        return Transcript(entries: entries)
    }
}
