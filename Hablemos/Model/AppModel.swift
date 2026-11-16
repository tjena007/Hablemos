import Foundation
import HablemosCore
import Observation
import SwiftData

enum Route {
    case home, modelSetup, warmup, conversation, summary, spike
}

enum HomeTab {
    case today, path, phrases, me
}

@MainActor
@Observable
final class AppModel {
    var route: Route = ProcessInfo.processInfo.arguments.contains("-autoSpike") ? .spike : .home
    var tab: HomeTab = .today
    var errorMessage: String?
    private(set) var setup: SessionSetup?
    private(set) var result: SessionResult?
    private(set) var warmupScenario: ScenarioConfig?
    private(set) var warmupReview: [WarmupItem] = []
    private(set) var warmupLocale = Locale(identifier: "es-MX")
    let engineHost = LiteRTEngineHost()
    private(set) var warmupDoneOn = UserDefaults.standard.object(forKey: "warmupDoneOn") as? Date {
        didSet { UserDefaults.standard.set(warmupDoneOn, forKey: "warmupDoneOn") }
    }

    /// Today's warm-up is done but the conversation isn't, so the session resumes at Lucía.
    var isWarmupDoneToday: Bool { warmupDoneOn.map(Calendar.current.isDateInToday) ?? false }

    static let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }()

    func go(_ route: Route) {
        self.route = route
    }

    func finish(with result: SessionResult) {
        self.result = result
        warmupDoneOn = nil
        route = .summary
    }

    func beginSession(useE2B: Bool, useApple: Bool, context: ModelContext) {
        let variant: ModelVariant = useE2B ? .e2b : .e4b
        if !useApple && !Self.isSimulator && !ModelStore.isInstalled(variant) {
            route = .modelSetup
        } else if isWarmupDoneToday {
            startConversation(context: context)
        } else {
            startWarmup(context: context)
        }
    }

    func startWarmup(context: ModelContext) {
        do {
            let profile = try ProgressStore(context: context).profile()
            guard let scenario = LevelsConfig.default.defaultScenario(for: profile.level) else { throw SetupError.noScenario(profile.level) }
            warmupScenario = scenario
            warmupReview = try Self.reviewItems(context: context)
            warmupLocale = Locale(identifier: profile.localeIdentifier)
            route = .warmup
        } catch {
            errorMessage = "Could not start the warm-up: \(error)"
        }
    }

    private static let maxReviewItems = 5

    static func reviewItems(context: ModelContext) throws -> [WarmupItem] {
        let correctionRole = Turn.correctionRole
        let descriptor = FetchDescriptor<Turn>(
            predicate: #Predicate { $0.roleRaw == correctionRole },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        var seen = Set<String>()
        return try context.fetch(descriptor).compactMap { $0.correction }
            .filter { seen.insert($0.right.lowercased()).inserted }
            .prefix(maxReviewItems)
            .map { WarmupItem($0.right, "You said “\($0.wrong)”. \($0.explanation)") }
    }

    func makeWarmupSTT(scripted: [String]) -> SpeechToText {
        #if targetEnvironment(simulator)
        MockSpeechToText(scripted: scripted)
        #else
        SpeechAnalyzerSpeechToText()
        #endif
    }

    func startConversation(context: ModelContext) {
        warmupDoneOn = .now
        do {
            let store = ProgressStore(context: context)
            let profile = try store.profile()
            let levels = LevelsConfig.default
            guard let levelConfig = levels.config(for: profile.level),
                  let scenario = levels.defaultScenario(for: profile.level)
            else { throw SetupError.noScenario(profile.level) }
            let stats = try context.fetch(FetchDescriptor<MistakeStat>(sortBy: [SortDescriptor(\.count, order: .reverse)]))
            let config = SessionConfig(
                scenario: scenario,
                level: levelConfig,
                weakSpots: stats.prefix(PromptBuilder.maxWeakSpots).map { MistakeTally.displayName(for: $0.category) },
                locale: Locale(identifier: profile.localeIdentifier),
                ttsRateOverride: profile.ttsRateOverride,
                focusWords: Warmup.forScenario(scenario.id).focusWords,
                opening: Self.opening(for: scenario)
            )
            setup = SessionSetup(config: config, services: makeServices(variant: profile.useE2BModel ? .e2b : .e4b, useApple: profile.useAppleModel))
            route = .conversation
        } catch {
            errorMessage = "Could not start the session: \(error)"
        }
    }

    private func makeServices(variant: ModelVariant, useApple: Bool) -> SessionServices {
        #if targetEnvironment(simulator)
        return .mock
        #else
        let host = engineHost
        let stt = SpeechAnalyzerSpeechToText()
        return SessionServices(
            stt: stt,
            sttErrors: stt.errors,
            lm: useApple ? AppleLanguageModel() : LiteRTLanguageModel(host: host),
            prepare: useApple ? { @Sendable in try AppleLanguageModel.checkAvailable() } : { @Sendable in
                if await host.loadedVariant != variant { try await host.load(variant) }
            },
            isLive: true
        )
        #endif
    }

    private static func opening(for scenario: ScenarioConfig) -> String {
        scenario.id == "cafe" ? "¡Hola! Bienvenido al café. ¿Qué te pongo?" : "¡Hola! Soy Lucía. ¿Empezamos?"
    }

    enum SetupError: Error {
        case noScenario(CEFRLevel)
    }
}
