import Foundation

public enum PromptBuilder {
    public static let maxWeakSpots = 3

    public static func systemPrompt(level: LevelConfig, scenario: ScenarioConfig, weakSpots: [String] = [], focusWords: [String] = []) -> String {
        var lines = [
            "You are Lucía, a friendly barista in Madrid having a spoken conversation with a Spanish learner.",
            "Learner level: \(level.level.rawValue). Scenario: \(scenario.description).",
            "Rules:",
            "- Reply ONLY in Spanish, \(level.maxSentences) short sentences max, using \(level.grammarScope).",
            "- Stay in character and keep the conversation moving with a question.",
            "- If the learner made a meaningful mistake, add a final line exactly in this format:",
            "  CORRECTION: <wrong phrase> => <correct phrase> | <one short English explanation>",
            "- Correct at most one mistake per turn; skip trivial ones.",
            "- If the learner writes in English, answer in simple Spanish and gently encourage Spanish.",
        ]
        let spots = weakSpots.prefix(maxWeakSpots)
        if !spots.isEmpty {
            lines.append("- Naturally create chances to practice: \(spots.joined(separator: ", ")).")
        }
        if !focusWords.isEmpty {
            lines.append("- The learner just practiced these words; use them and keep your sentences very simple: \(focusWords.joined(separator: ", ")).")
        }
        return lines.joined(separator: "\n")
    }

    // The summary is sent as a user message: chat APIs expect the first turn to be the user's.
    public static func buildHistory(turns: [ChatMessage], summary: String?, keepLast: Int = 16) -> [ChatMessage] {
        let recent = Array(turns.suffix(keepLast))
        guard turns.count > keepLast, let summary else { return recent }
        return [ChatMessage(role: .user, text: "Earlier in this conversation: \(summary)")] + recent
    }
}
