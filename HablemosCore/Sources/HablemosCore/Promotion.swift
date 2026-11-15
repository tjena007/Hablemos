import Foundation

public enum CEFRLevel: String, Codable, CaseIterable, Sendable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2"

    public var next: CEFRLevel? {
        let all = CEFRLevel.allCases
        return all.firstIndex(of: self).flatMap { $0 + 1 < all.count ? all[$0 + 1] : nil }
    }
}

public struct PromotionRule: Sendable, Equatable {
    public var maxErrorsPerTurn: Double
    public var minWordsPerTurn: Double
    public var strongSessionsRequired: Int

    public init(maxErrorsPerTurn: Double = 2, minWordsPerTurn: Double = 8, strongSessionsRequired: Int = 3) {
        self.maxErrorsPerTurn = maxErrorsPerTurn
        self.minWordsPerTurn = minWordsPerTurn
        self.strongSessionsRequired = strongSessionsRequired
    }

    public func isStrong(_ metrics: SessionMetrics) -> Bool {
        metrics.turns > 0
            && metrics.errorsPerTurn < maxErrorsPerTurn
            && metrics.wordsPerTurn >= minWordsPerTurn
    }

    public struct Outcome: Equatable, Sendable {
        public let streak: Int
        public let unlocksNextLevel: Bool
    }

    public func apply(streak: Int, session: SessionMetrics) -> Outcome {
        guard isStrong(session) else { return Outcome(streak: 0, unlocksNextLevel: false) }
        let updated = streak + 1
        let unlocks = updated >= strongSessionsRequired
        return Outcome(streak: unlocks ? 0 : updated, unlocksNextLevel: unlocks)
    }
}
