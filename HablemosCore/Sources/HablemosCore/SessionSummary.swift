import Foundation

public struct MistakeEntry: Codable, Equatable, Sendable {
    public let original: String
    public let corrected: String
    public let category: String
    public let explanation: String

    public init(original: String, corrected: String, category: String, explanation: String) {
        self.original = original
        self.corrected = corrected
        self.category = category
        self.explanation = explanation
    }
}

public struct SessionSummary: Codable, Equatable, Sendable {
    public let mistakes: [MistakeEntry]
    public let newWords: [String]
    public let estimatedLevel: CEFRLevel

    public init(mistakes: [MistakeEntry], newWords: [String], estimatedLevel: CEFRLevel) {
        self.mistakes = mistakes
        self.newWords = newWords
        self.estimatedLevel = estimatedLevel
    }

    public static let jsonSchema = """
    {
      "type": "object",
      "properties": {
        "mistakes": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "original": { "type": "string", "minLength": 1 },
              "corrected": { "type": "string", "minLength": 1 },
              "category": { "type": "string", "minLength": 1 },
              "explanation": { "type": "string", "minLength": 1 }
            },
            "required": ["original", "corrected", "category", "explanation"],
            "additionalProperties": false
          }
        },
        "newWords": { "type": "array", "items": { "type": "string", "minLength": 1 } },
        "estimatedLevel": { "type": "string", "enum": ["A1", "A2", "B1", "B2"] }
      },
      "required": ["mistakes", "newWords", "estimatedLevel"],
      "additionalProperties": false
    }
    """
}

public enum SessionSummaryError: Error, Equatable, CustomStringConvertible {
    case noJSONObject
    case malformed(String)
    case emptyField(String)
    case invalidLevel(String)

    public var description: String {
        switch self {
        case .noJSONObject: "No JSON object found in model output"
        case .malformed(let detail): "Summary JSON does not match the expected shape: \(detail)"
        case .emptyField(let field): "Summary field '\(field)' is empty"
        case .invalidLevel(let value): "Invalid estimatedLevel '\(value)'; expected A1, A2, B1 or B2"
        }
    }
}

public enum SessionSummaryParser {
    private struct Raw: Decodable {
        struct Mistake: Decodable {
            let original: String
            let corrected: String
            let category: String
            let explanation: String
        }
        let mistakes: [Mistake]
        let newWords: [String]
        let estimatedLevel: String
    }

    public static func parse(_ raw: String) throws -> SessionSummary {
        guard let json = firstJSONObject(in: raw) else { throw SessionSummaryError.noJSONObject }
        let decoded: Raw
        do {
            decoded = try JSONDecoder().decode(Raw.self, from: Data(json.utf8))
        } catch {
            throw SessionSummaryError.malformed(String(describing: error))
        }
        guard let level = CEFRLevel(rawValue: decoded.estimatedLevel) else {
            throw SessionSummaryError.invalidLevel(decoded.estimatedLevel)
        }
        let mistakes = try decoded.mistakes.map { m in
            for (name, value) in [("original", m.original), ("corrected", m.corrected), ("category", m.category), ("explanation", m.explanation)] {
                try requireNonEmpty(value, field: "mistakes.\(name)")
            }
            return MistakeEntry(original: m.original, corrected: m.corrected, category: m.category, explanation: m.explanation)
        }
        for word in decoded.newWords { try requireNonEmpty(word, field: "newWords") }
        return SessionSummary(mistakes: mistakes, newWords: decoded.newWords, estimatedLevel: level)
    }

    private static func requireNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw SessionSummaryError.emptyField(field) }
    }

    private static func firstJSONObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = start
        while index < text.endIndex {
            let char = text[index]
            if inString {
                if escaped { escaped = false } else if char == "\\" { escaped = true } else if char == "\"" { inString = false }
            } else if char == "\"" {
                inString = true
            } else if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(text[start...index]) }
            }
            index = text.index(after: index)
        }
        return nil
    }
}

public enum SessionSummaryPrompt {
    public static func make(transcript: [ChatMessage]) -> String {
        let lines = transcript.map { "\($0.role == .user ? "Learner" : "Tutor"): \($0.text)" }
        return """
        Below is a Spanish practice conversation between a learner and a tutor. Analyze the learner's Spanish.
        Respond with ONLY one strict JSON object, no markdown and no extra text, matching this schema:
        \(SessionSummary.jsonSchema)
        Rules:
        - "mistakes": the learner's meaningful mistakes. "category" is snake_case such as ser_vs_estar; "explanation" is one short English sentence.
        - "newWords": useful Spanish words or phrases the learner met in this conversation.
        - "estimatedLevel": the learner's level, one of A1, A2, B1, B2.

        Conversation:
        \(lines.joined(separator: "\n"))
        """
    }
}
