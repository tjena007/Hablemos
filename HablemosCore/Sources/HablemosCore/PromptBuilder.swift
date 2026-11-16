import Foundation

public enum PromptBuilder {
    public static let maxWeakSpots = 3

    public static func systemPrompt(level: LevelConfig, scenario: ScenarioConfig, weakSpots: [String] = [], focusWords: [String] = [], wrapUp: Bool = false) -> String {
        var lines = [
            "You are Lucía, \(scenario.role), having a spoken conversation with a Spanish learner.",
            "Learner level: \(level.level.rawValue). Scenario: \(scenario.description).",
            "Rules:",
            "- Reply ONLY in Spanish, \(level.maxSentences) short sentences max, using \(level.grammarScope).",
            wrapUp
                ? "- This is your last turn: react to what they said, then say a warm goodbye. Do NOT ask a question."
                : "- Stay in character and keep the conversation moving with a question.",
            "- Never repeat a question you already asked; move on to something new.",
            "- If the learner made a meaningful mistake, add a final line exactly in this format:",
            "  CORRECTION: <wrong phrase> => <correct phrase> | <one short English explanation>",
            "- Correct at most one mistake per turn; skip trivial ones.",
            "- If the learner writes in English, answer in simple Spanish and gently encourage Spanish.",
        ]
        if !scenario.missions.isEmpty {
            lines.append("- The learner's missions: \(scenario.missions.joined(separator: "; ")). Give them natural chances to do each one.")
        }
        let spots = weakSpots.prefix(maxWeakSpots)
        if !spots.isEmpty {
            lines.append("- Naturally create chances to practice: \(spots.joined(separator: ", ")).")
        }
        if !focusWords.isEmpty {
            lines.append("- The learner just practiced these words; use them and keep your sentences very simple: \(focusWords.joined(separator: ", ")).")
            if level.level == .a1 {
                lines.append("- Build your replies from those words plus only the most basic everyday words (sí, no, y, muy, bien, ¿y tú?). Use at most one new word per reply, and keep each sentence under 8 words.")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Asks for short replies the learner could give to Lucía's last line, one per line as `Spanish | English`.
    public static func suggestionsPrompt(level: CEFRLevel, luciaSaid: String) -> String {
        """
        Lucía said: "\(luciaSaid)"
        Suggest 3 short, different replies a \(level.rawValue) Spanish learner could say back.
        Output exactly 3 lines in this format, nothing else:
        <reply in Spanish> | <English translation>
        """
    }

    public static func parseSuggestions(_ raw: String) -> [WarmupItem] {
        raw.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { return nil }
            let spanish = parts[0]
                .replacingOccurrences(of: #"^([-*•]|\d+[.)])\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"<> "))
            let english = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"<> "))
            return spanish.isEmpty || english.isEmpty ? nil : WarmupItem(spanish, english)
        }
    }

    // The summary is sent as a user message: chat APIs expect the first turn to be the user's.
    public static func buildHistory(turns: [ChatMessage], summary: String?, keepLast: Int = 16) -> [ChatMessage] {
        let recent = Array(turns.suffix(keepLast))
        guard turns.count > keepLast, let summary else { return recent }
        return [ChatMessage(role: .user, text: "Earlier in this conversation: \(summary)")] + recent
    }
}
