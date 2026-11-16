import Foundation
import HablemosCore
import Observation

struct SpokenLine: Equatable {
    let id = UUID()
    let text: String
}

enum FeedbackStyle {
    case prompt, recast, explicit
}

enum ChatItem: Identifiable, Equatable {
    case lucia(id: UUID = UUID(), text: String, highlight: String?)
    case user(id: UUID = UUID(), text: String, errorWord: String?)
    case retryCard(id: UUID = UUID())
    case correction(id: UUID = UUID(), Correction)
    case recastNote(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .lucia(let id, _, _), .user(let id, _, _), .retryCard(let id), .correction(let id, _), .recastNote(let id):
            id
        }
    }
}

@MainActor
@Observable
final class ConversationViewModel {
    private(set) var items: [ChatItem]
    private(set) var isListening = false
    private(set) var isReplying = false
    private(set) var isPreparing = false
    private(set) var isFinishing = false
    private(set) var liveTranscript = ""
    private(set) var level: Float = 0
    private(set) var translations: [UUID: String] = [:]
    var errorMessage: String?
    var speech: SpeechPlayer?

    private let style: FeedbackStyle
    private let config: SessionConfig
    private let services: SessionServices
    private var history: [ChatMessage]
    private var userTurns: [UserTurn] = []
    private var corrections: [Correction] = []
    private var listenTask: Task<String, Never>?
    private var replyTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var isPrepared = false
    private var lastLuciaDone = Date()
    private var pendingPause = 0.0
    private let startedAt = Date()

    init(style: FeedbackStyle = .explicit, config: SessionConfig = .demo, services: SessionServices = .mock) {
        self.style = style
        self.config = config
        self.services = services
        items = [.lucia(text: config.opening, highlight: nil)]
        history = [ChatMessage(role: .tutor, text: config.opening)]
    }

    func prepare() async {
        guard !isPrepared else { return }
        isPrepared = true
        if let errors = services.sttErrors {
            errorTask = Task { [weak self] in
                for await error in errors { self?.errorMessage = error.localizedDescription }
            }
        }
        if let prepare = services.prepare {
            isPreparing = true
            defer { isPreparing = false }
            do {
                try await prepare()
            } catch {
                errorMessage = "Could not load the model: \(error)"
                return
            }
        }
        lastLuciaDone = Date()
        speech?.say(config.opening, rate: config.ttsRate)
    }

    var scenario: ScenarioConfig { config.scenario }
    var levelName: String { config.level.level.rawValue }

    var latestLucia: (id: UUID, text: String)? {
        for item in items.reversed() {
            if case .lucia(let id, let text, _) = item { return (id, text) }
        }
        return nil
    }

    func translateLatest() async {
        guard let line = latestLucia, translations[line.id] == nil else { return }
        let system = "Translate the user's Spanish message into natural English. Output only the translation."
        var translated = ""
        do {
            for try await token in services.lm.stream(system: system, history: [], user: line.text) { translated += token }
        } catch {
            errorMessage = "Could not translate: \(error)"
            return
        }
        translations[line.id] = translated.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func beginListening() {
        guard !isListening, !isReplying, !isPreparing else { return }
        speech?.stop()
        isListening = true
        liveTranscript = ""
        pendingPause = Date().timeIntervalSince(lastLuciaDone)
        let stream = services.stt.startListening(locale: config.locale)
        listenTask = Task { [weak self] in
            var finalText = ""
            for await update in stream {
                finalText = update.text
                self?.liveTranscript = update.text
                self?.level = update.level
            }
            return finalText
        }
    }

    func endListening() async {
        guard isListening, let listenTask else { return }
        isListening = false
        level = 0
        await services.stt.stopListening()
        let heard = await listenTask.value
        liveTranscript = ""
        guard !heard.isEmpty else { return }
        replyTask = Task { await reply(to: heard) }
        await replyTask?.value
    }

    func pause() async {
        cancelGeneration()
        errorTask?.cancel()
        guard isListening else { return }
        isListening = false
        await services.stt.stopListening()
    }

    func cancelGeneration() {
        replyTask?.cancel()
        speech?.stop()
    }

    func finish(store: ProgressStore) async throws -> SessionResult {
        isFinishing = true
        defer { isFinishing = false }
        cancelGeneration()
        errorTask?.cancel()

        let levelBefore = try store.profile().level
        let summary: (value: SessionSummary?, json: String?, error: String?) = userTurns.isEmpty ? (nil, nil, nil) : await summarize()
        let mistakes = summary.value?.mistakes ?? corrections.map {
            MistakeEntry(original: $0.wrong, corrected: $0.right, category: "uncategorized", explanation: $0.explanation)
        }
        let metrics = MetricsCalculator.compute(userTurns: userTurns, mistakeCount: mistakes.count)
        let duration = Date().timeIntervalSince(startedAt)

        if !userTurns.isEmpty {
            try store.record(
                date: .now,
                scenarioID: config.scenario.id,
                level: levelBefore,
                durationSeconds: duration,
                metrics: metrics,
                summaryJSON: summary.json,
                turns: turnRecords() + correctionRecords(mistakes),
                mistakes: mistakes.map { MistakeRecord(category: $0.category, example: "\($0.original) → \($0.corrected)") },
                vocab: summary.value?.newWords ?? []
            )
        }
        // The session is already saved, so a failed export is reported on the summary rather than thrown.
        let exportError: String? = userTurns.isEmpty ? nil : {
            do {
                try store.exportData().write(to: ProgressStore.autoExportURL, options: .atomic)
                return nil
            } catch {
                return "Could not update the progress export: \(error)"
            }
        }()
        let profile = try store.profile()
        let rule = store.rule
        return SessionResult(
            scenarioTitle: config.scenario.title,
            level: levelBefore,
            durationSeconds: duration,
            metrics: metrics,
            mistakes: mistakes,
            newWords: summary.value?.newWords ?? [],
            isStrong: rule.isStrong(metrics),
            streak: profile.level == levelBefore ? profile.strongSessionStreak : rule.strongSessionsRequired,
            streakRequired: rule.strongSessionsRequired,
            unlockedLevel: profile.level == levelBefore ? nil : profile.level,
            summaryError: summary.error,
            exportError: exportError
        )
    }

    private func summarize() async -> (value: SessionSummary?, json: String?, error: String?) {
        let prompt = SessionSummaryPrompt.make(transcript: history)
        var lastError = ""
        for _ in 0..<2 {
            do {
                let raw = try await services.lm.completeJSON(prompt: prompt, jsonSchema: SessionSummary.jsonSchema)
                return (try SessionSummaryParser.parse(raw), raw, nil)
            } catch {
                lastError = "\(error)"
            }
        }
        return (nil, nil, "Summary failed: \(lastError)")
    }

    private func correctionRecords(_ mistakes: [MistakeEntry]) -> [TurnRecord] {
        mistakes.map {
            TurnRecord(
                roleRaw: Turn.correctionRole, text: $0.corrected,
                correction: Correction(wrong: $0.original, right: $0.corrected, explanation: $0.explanation), timestamp: .now
            )
        }
    }

    private func turnRecords() -> [TurnRecord] {
        history.map { TurnRecord(roleRaw: $0.role.rawValue, text: $0.text, correction: nil, timestamp: .now) }
    }

    private func reply(to heard: String) async {
        isReplying = true
        defer { isReplying = false }
        items.append(.user(text: heard, errorWord: nil))
        userTurns.append(UserTurn(text: heard, pauseBeforeSeconds: pendingPause))

        let system = PromptBuilder.systemPrompt(level: config.level, scenario: config.scenario, weakSpots: config.weakSpots, focusWords: config.focusWords)
        let context = PromptBuilder.buildHistory(turns: history, summary: nil)
        var raw = ""
        var chunker = SentenceChunker()
        do {
            for try await token in services.lm.stream(system: system, history: context, user: heard) {
                raw += token
                for sentence in chunker.feed(token) { speech?.enqueue(sentence, rate: config.ttsRate) }
            }
            if let rest = chunker.flush() { speech?.enqueue(rest, rate: config.ttsRate) }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Lucía could not reply: \(error)"
            return
        }
        guard !Task.isCancelled else { return }

        history.append(ChatMessage(role: .user, text: heard))
        let parsed = ReplyParser.parse(raw)
        history.append(ChatMessage(role: .tutor, text: parsed.spoken))
        if let correction = parsed.correction {
            corrections.append(correction)
            underlineError(of: correction, in: heard)
        }
        append(parsed)
        lastLuciaDone = Date()
    }

    private func underlineError(of correction: Correction, in heard: String) {
        let rightWords = Set(correction.right.lowercased().split(separator: " ").map(String.init))
        let word = correction.wrong.split(separator: " ").map(String.init).first { !rightWords.contains($0.lowercased()) }
        guard let word, let index = items.lastIndex(where: { if case .user = $0 { true } else { false } }) else { return }
        items[index] = .user(text: heard, errorWord: word)
    }

    private func append(_ parsed: ParsedReply) {
        switch style {
        case .explicit:
            if let correction = parsed.correction { items.append(.correction(correction)) }
            items.append(.lucia(text: parsed.spoken, highlight: nil))
        case .prompt:
            items.append(.lucia(text: parsed.spoken, highlight: nil))
            items.append(.retryCard())
        case .recast:
            items.append(.lucia(text: parsed.spoken, highlight: "está"))
            items.append(.recastNote())
        }
    }
}
