import Foundation
import HablemosCore
import LiteRTLM

actor LiteRTEngineHost {
    private var engine: Engine?
    private(set) var loadedVariant: ModelVariant?

    var isLoaded: Bool { engine != nil }

    func load(_ variant: ModelVariant, backend: Backend = .gpu, maxNumTokens: Int = 2048) async throws {
        let config = try EngineConfig(
            modelPath: ModelStore.url(for: variant).path,
            backend: backend,
            maxNumTokens: maxNumTokens,
            cacheDir: FileManager.default.temporaryDirectory.path
        )
        // A second engine cannot be created while the first is alive (litert_lm_engine_create fails).
        engine = nil
        loadedVariant = nil
        let newEngine = Engine(engineConfig: config)
        try await newEngine.initialize()
        engine = newEngine
        loadedVariant = variant
    }

    func unload() {
        engine = nil
        loadedVariant = nil
    }

    func makeConversation(system: String, history: [ChatMessage], responseFormat: Bool = false) async throws -> Conversation {
        guard let engine else { throw HostError.notLoaded }
        let initial = history.map { Message($0.text, role: $0.role == .user ? .user : .model) }
        let config = ConversationConfig(
            systemMessage: system.isEmpty ? nil : Message(system, role: .system),
            initialMessages: initial,
            samplerConfig: try SamplerConfig(topK: 40, topP: 0.95, temperature: 0.7),
            enableResponseFormat: responseFormat
        )
        return try await engine.createConversation(with: config)
    }

    enum HostError: Error { case notLoaded }
}

struct LiteRTLanguageModel: LanguageModel {
    let host: LiteRTEngineHost

    func stream(system: String, history: [ChatMessage], user: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let conversation = try await host.makeConversation(system: system, history: history)
                    try await withTaskCancellationHandler {
                        for try await chunk in conversation.sendMessageStream(Message(user)) {
                            continuation.yield(chunk.toString)
                        }
                    } onCancel: {
                        try? conversation.cancel()
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
        let conversation = try await host.makeConversation(system: "", history: [], responseFormat: true)
        let response = try await conversation.sendMessage(Message(prompt), responseFormat: ResponseFormat.json(schema: jsonSchema))
        return response.toString
    }
}
