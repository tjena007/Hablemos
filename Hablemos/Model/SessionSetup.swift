import Foundation
import HablemosCore

struct SessionConfig {
    let scenario: ScenarioConfig
    let level: LevelConfig
    let weakSpots: [String]
    let locale: Locale
    let ttsRateOverride: Float?
    let focusWords: [String]
    let opening: String

    var ttsRate: Float { ttsRateOverride ?? level.ttsRate }

    static var demo: SessionConfig {
        let levels = LevelsConfig.default
        return SessionConfig(
            scenario: levels.scenarios(for: .a1)[0],
            level: levels.config(for: .a1)!,
            weakSpots: ["ser vs estar"],
            locale: Locale(identifier: "es-MX"),
            ttsRateOverride: nil,
            focusWords: [],
            opening: "¡Perfecto! ¿Es para tomar aquí o para llevar?"
        )
    }
}

struct SessionServices {
    let stt: SpeechToText
    let sttErrors: AsyncStream<any Error>?
    let lm: LanguageModel
    let prepare: (@Sendable () async throws -> Void)?
    let isLive: Bool

    static var mock: SessionServices {
        SessionServices(
            stt: MockSpeechToText(scripted: [
                "Para aquí. El cruasán es muy rico.",
                "Quiero pagar con tarjeta, por favor.",
                "Muchas gracias, hasta luego.",
            ]),
            sttErrors: nil,
            lm: MockLanguageModel(replies: [
                "¡Me alegro! Son cuatro euros con cincuenta.\nCORRECTION: es muy rico => está muy rico | Use estar for how food tastes right now.",
                "Claro que sí. Aquí tiene el datáfono.",
                "¡Hasta luego! Que tengas un buen día.",
            ]),
            prepare: nil,
            isLive: false
        )
    }
}

struct SessionSetup {
    let config: SessionConfig
    let services: SessionServices
}

struct SessionResult {
    let scenarioTitle: String
    let level: CEFRLevel
    let durationSeconds: Double
    let metrics: SessionMetrics
    let mistakes: [MistakeEntry]
    let newWords: [String]
    let isStrong: Bool
    let streak: Int
    let streakRequired: Int
    let unlockedLevel: CEFRLevel?
    let summaryError: String?
    let exportError: String?

    static var demo: SessionResult {
        SessionResult(
            scenarioTitle: "En el café",
            level: .a1,
            durationSeconds: 540,
            metrics: SessionMetrics(turns: 14, wordsPerTurn: 8.6, errorsPerTurn: 1.2, englishSwitches: 0, averagePauseSeconds: 2.4),
            mistakes: [
                MistakeEntry(original: "es muy rico", corrected: "está muy rico", category: "ser_vs_estar", explanation: "estar for how food tastes now"),
                MistakeEntry(original: "una café", corrected: "un café", category: "gender_agreement", explanation: "café is masculine"),
            ],
            newWords: DemoData.newWords,
            isStrong: true,
            streak: 2,
            streakRequired: 3,
            unlockedLevel: nil,
            summaryError: nil,
            exportError: nil
        )
    }
}
