import Foundation
import HablemosCore
import SwiftData

@Model
final class LearnerProfile {
    var levelRaw: String = CEFRLevel.a1.rawValue
    var strongSessionStreak: Int = 0
    var dayStreak: Int = 0
    var lastPracticeDate: Date?
    var localeIdentifier: String = "es-MX"
    var voiceIdentifier: String?
    var ttsRateOverride: Float?
    var useE2BModel: Bool = false
    var useAppleModel: Bool = false

    var level: CEFRLevel {
        get { CEFRLevel(rawValue: levelRaw) ?? .a1 }
        set { levelRaw = newValue.rawValue }
    }

    init(level: CEFRLevel = .a1) {
        levelRaw = level.rawValue
    }
}

@Model
final class PracticeSession {
    var id: UUID = UUID()
    var date: Date = Date.now
    var scenarioID: String = ""
    var levelRaw: String = CEFRLevel.a1.rawValue
    var durationSeconds: Double = 0
    var metricsData: Data = Data()
    var summaryJSON: String?
    @Relationship(deleteRule: .cascade, inverse: \Turn.session)
    var turns: [Turn]? = []

    var level: CEFRLevel {
        get { CEFRLevel(rawValue: levelRaw) ?? .a1 }
        set { levelRaw = newValue.rawValue }
    }

    var learnerTurnCount: Int { (turns ?? []).filter { $0.roleRaw == ChatMessage.Role.user.rawValue }.count }

    var metrics: SessionMetrics {
        get throws { try JSONDecoder().decode(SessionMetrics.self, from: metricsData) }
    }

    init(
        id: UUID = UUID(), date: Date, scenarioID: String, level: CEFRLevel,
        durationSeconds: Double, metrics: SessionMetrics, summaryJSON: String? = nil
    ) throws {
        self.id = id
        self.date = date
        self.scenarioID = scenarioID
        self.levelRaw = level.rawValue
        self.durationSeconds = durationSeconds
        self.metricsData = try JSONEncoder().encode(metrics)
        self.summaryJSON = summaryJSON
    }
}

@Model
final class Turn {
    static let correctionRole = "correction"

    var roleRaw: String = ""
    var text: String = ""
    var correctionWrong: String?
    var correctionRight: String?
    var correctionExplanation: String?
    var timestamp: Date = Date.now
    var session: PracticeSession?

    var correction: Correction? {
        guard let wrong = correctionWrong, let right = correctionRight, let explanation = correctionExplanation else {
            return nil
        }
        return Correction(wrong: wrong, right: right, explanation: explanation)
    }

    init(roleRaw: String, text: String, correction: Correction? = nil, timestamp: Date) {
        self.roleRaw = roleRaw
        self.text = text
        self.correctionWrong = correction?.wrong
        self.correctionRight = correction?.right
        self.correctionExplanation = correction?.explanation
        self.timestamp = timestamp
    }
}

@Model
final class MistakeStat {
    @Attribute(.unique) var category: String = ""
    var example: String = ""
    var count: Int = 0
    var lastSeen: Date = Date.now

    init(category: String, example: String, count: Int, lastSeen: Date) {
        self.category = category
        self.example = example
        self.count = count
        self.lastSeen = lastSeen
    }
}

@Model
final class VocabItem {
    @Attribute(.unique) var phrase: String = ""
    var firstSeen: Date = Date.now
    var timesUsed: Int = 0

    init(phrase: String, firstSeen: Date, timesUsed: Int) {
        self.phrase = phrase
        self.firstSeen = firstSeen
        self.timesUsed = timesUsed
    }
}

enum PersistenceSchema {
    static let models: [any PersistentModel.Type] = [
        LearnerProfile.self, PracticeSession.self, Turn.self, MistakeStat.self, VocabItem.self,
    ]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
