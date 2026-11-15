import Foundation

public struct UserTurn: Sendable, Equatable {
    public let text: String
    public let pauseBeforeSeconds: Double

    public init(text: String, pauseBeforeSeconds: Double) {
        self.text = text
        self.pauseBeforeSeconds = pauseBeforeSeconds
    }
}

public struct SessionMetrics: Codable, Equatable, Sendable {
    public let turns: Int
    public let wordsPerTurn: Double
    public let errorsPerTurn: Double
    public let englishSwitches: Int
    public let averagePauseSeconds: Double

    public init(turns: Int, wordsPerTurn: Double, errorsPerTurn: Double, englishSwitches: Int, averagePauseSeconds: Double) {
        self.turns = turns
        self.wordsPerTurn = wordsPerTurn
        self.errorsPerTurn = errorsPerTurn
        self.englishSwitches = englishSwitches
        self.averagePauseSeconds = averagePauseSeconds
    }
}

public enum EnglishDetector {
    private static let stopwords: Set<String> = [
        "the", "is", "are", "and", "to", "of", "in", "it", "that", "you", "i", "this", "what", "how",
        "can", "do", "does", "my", "me", "want", "like", "would", "have", "with", "for", "please",
    ]

    public static func isEnglish(_ text: String) -> Bool {
        let words = text.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
        guard !words.isEmpty else { return false }
        let hits = words.filter(stopwords.contains).count
        return hits >= 2 && Double(hits) / Double(words.count) >= 0.3
    }
}

public enum MetricsCalculator {
    public static func compute(userTurns: [UserTurn], mistakeCount: Int) -> SessionMetrics {
        guard !userTurns.isEmpty else {
            return SessionMetrics(turns: 0, wordsPerTurn: 0, errorsPerTurn: 0, englishSwitches: 0, averagePauseSeconds: 0)
        }
        let count = Double(userTurns.count)
        let words = userTurns.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
        let pauses = userTurns.reduce(0) { $0 + $1.pauseBeforeSeconds }
        return SessionMetrics(
            turns: userTurns.count,
            wordsPerTurn: Double(words) / count,
            errorsPerTurn: Double(mistakeCount) / count,
            englishSwitches: userTurns.filter { EnglishDetector.isEnglish($0.text) }.count,
            averagePauseSeconds: pauses / count
        )
    }
}
