import Foundation

public struct Correction: Codable, Equatable, Sendable {
    public let wrong: String
    public let right: String
    public let explanation: String

    public init(wrong: String, right: String, explanation: String) {
        self.wrong = wrong
        self.right = right
        self.explanation = explanation
    }
}

public struct ParsedReply: Equatable, Sendable {
    public let spoken: String
    public let correction: Correction?
}

public enum ReplyParser {
    private static let marker = "CORRECTION:"

    public static func parse(_ raw: String) -> ParsedReply {
        var spokenLines: [String] = []
        var correction: Correction?

        for line in raw.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(marker) {
                correction = correction ?? parseCorrection(String(trimmed.dropFirst(marker.count)))
            } else if !trimmed.isEmpty {
                spokenLines.append(trimmed)
            }
        }
        return ParsedReply(spoken: spokenLines.joined(separator: " "), correction: correction)
    }

    private static func parseCorrection(_ body: String) -> Correction? {
        let arrowParts = body.components(separatedBy: "=>")
        guard arrowParts.count == 2 else { return nil }
        let explanationParts = arrowParts[1].split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let wrong = arrowParts[0].trimmingCharacters(in: .whitespaces)
        let right = explanationParts[0].trimmingCharacters(in: .whitespaces)
        guard !wrong.isEmpty, !right.isEmpty else { return nil }
        let explanation = explanationParts.count > 1
            ? explanationParts[1].trimmingCharacters(in: .whitespaces)
            : ""
        return Correction(wrong: wrong, right: right, explanation: explanation)
    }
}
