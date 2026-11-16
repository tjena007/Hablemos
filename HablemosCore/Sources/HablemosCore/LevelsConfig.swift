import Foundation

public struct LevelConfig: Codable, Equatable, Sendable {
    public enum EnglishHelp: String, Codable, Sendable { case allowed, discouraged, none }

    public let level: CEFRLevel
    public let maxSentences: Int
    public let grammarScope: String
    public let ttsRate: Float
    public let englishHelp: EnglishHelp
    public let note: String

    public init(level: CEFRLevel, maxSentences: Int, grammarScope: String, ttsRate: Float, englishHelp: EnglishHelp, note: String) {
        self.level = level
        self.maxSentences = maxSentences
        self.grammarScope = grammarScope
        self.ttsRate = ttsRate
        self.englishHelp = englishHelp
        self.note = note
    }
}

public struct ScenarioConfig: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let level: CEFRLevel
    public let description: String
    /// Who Lucía plays, e.g. "a friendly barista in Madrid".
    public let role: String
    /// What the learner should manage to say; Lucía steers toward them.
    public let missions: [String]

    public init(id: String, title: String, subtitle: String, level: CEFRLevel, description: String,
                role: String = ScenarioConfig.defaultRole, missions: [String] = []) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.level = level
        self.description = description
        self.role = role
        self.missions = missions
    }

    public static let defaultRole = "a friendly conversation partner"

    private enum CodingKeys: String, CodingKey { case id, title, subtitle, level, description, role, missions }

    // Hand-written scenario files may leave out role and missions.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            subtitle: try container.decode(String.self, forKey: .subtitle),
            level: try container.decode(CEFRLevel.self, forKey: .level),
            description: try container.decode(String.self, forKey: .description),
            role: try container.decodeIfPresent(String.self, forKey: .role) ?? Self.defaultRole,
            missions: try container.decodeIfPresent([String].self, forKey: .missions) ?? []
        )
    }
}

public struct LevelsConfig: Codable, Equatable, Sendable {
    public let levels: [LevelConfig]
    public let scenarios: [ScenarioConfig]

    public init(levels: [LevelConfig], scenarios: [ScenarioConfig]) {
        self.levels = levels
        self.scenarios = scenarios
    }

    public static func load(from data: Data) throws -> LevelsConfig {
        try JSONDecoder().decode(LevelsConfig.self, from: data)
    }

    public func config(for level: CEFRLevel) -> LevelConfig? {
        levels.first { $0.level == level }
    }

    public func scenarios(for level: CEFRLevel) -> [ScenarioConfig] {
        scenarios.filter { $0.level == level }
    }

    public func defaultScenario(for level: CEFRLevel) -> ScenarioConfig? {
        scenarios(for: level).first
    }

    public static let `default` = LevelsConfig(
        levels: [
            LevelConfig(level: .a1, maxSentences: 2, grammarScope: "present tense only", ttsRate: 0.38, englishHelp: .allowed,
                        note: "1-2 short sentences; English help allowed"),
            LevelConfig(level: .a2, maxSentences: 3, grammarScope: "present tense and the preterite", ttsRate: 0.42, englishHelp: .allowed,
                        note: "Adds the preterite; asks follow-up questions"),
            LevelConfig(level: .b1, maxSentences: 4, grammarScope: "mixed tenses", ttsRate: 0.46, englishHelp: .discouraged,
                        note: "Longer turns; sometimes disagrees with the learner"),
            LevelConfig(level: .b2, maxSentences: 5, grammarScope: "natural, unsimplified Spanish including idioms", ttsRate: 0.5, englishHelp: .none,
                        note: "Natural speed; no simplification"),
        ],
        scenarios: [
            ScenarioConfig(id: "cafe", title: "En el café", subtitle: "Order a coffee and a snack", level: .a1,
                           description: "the learner is ordering food and drinks at your café", role: "a friendly barista in Madrid"),
            ScenarioConfig(id: "introductions", title: "Preséntate", subtitle: "Introduce yourself", level: .a1,
                           description: "the learner is introducing themselves to you"),
            ScenarioConfig(id: "directions", title: "Direcciones", subtitle: "Ask how to get somewhere", level: .a2,
                           description: "the learner is asking you for directions around Madrid"),
            ScenarioConfig(id: "shopping", title: "De compras", subtitle: "Buy things in a shop", level: .a2,
                           description: "the learner is shopping and asking about prices and sizes"),
            ScenarioConfig(id: "weekend", title: "Tu fin de semana", subtitle: "Talk about your weekend", level: .a2,
                           description: "the learner is telling you what they did last weekend"),
            ScenarioConfig(id: "story", title: "Cuenta una historia", subtitle: "Tell a story", level: .b1,
                           description: "the learner is telling you a story about something that happened to them"),
            ScenarioConfig(id: "job", title: "Tu trabajo", subtitle: "Talk about your job", level: .b1,
                           description: "the learner is talking about their job and career"),
            ScenarioConfig(id: "plans", title: "Hacer planes", subtitle: "Make plans with a friend", level: .b1,
                           description: "the learner is making plans with you for the coming days"),
            ScenarioConfig(id: "open", title: "Conversación libre", subtitle: "Talk about anything", level: .b2,
                           description: "you are having a free, open conversation about any topic"),
            ScenarioConfig(id: "opinions", title: "Opiniones", subtitle: "Share and defend opinions", level: .b2,
                           description: "the learner is sharing opinions and you discuss them, including hypotheticals"),
        ]
    )
}
