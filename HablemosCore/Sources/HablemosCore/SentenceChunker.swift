import Foundation

public struct SentenceChunker: Sendable {
    private static let marker = "CORRECTION:"
    private static let terminators: Set<Character> = [".", "!", "?", "…"]
    private static let closers: Set<Character> = ["\"", "'", ")", "»", "”"]
    private static let abbreviations: Set<String> = ["sr", "sra", "srta", "dr", "dra", "lic", "ud", "uds", "prof"]

    private var buffer = ""
    private var atLineStart = true
    private var stopped = false

    public init() {}

    public mutating func feed(_ token: String) -> [String] {
        guard !stopped else { return [] }
        buffer += token
        var sentences: [String] = []
        while let sentence = nextSentence() { sentences.append(sentence) }
        return sentences
    }

    public mutating func flush() -> String? {
        defer { buffer = "" }
        guard !stopped else { return nil }
        trimLeadingWhitespace()
        if atLineStart && buffer.hasPrefix(Self.marker) { return nil }
        let rest = buffer.trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? nil : rest
    }

    private mutating func trimLeadingWhitespace() {
        while let first = buffer.first, first.isWhitespace {
            if first.isNewline { atLineStart = true }
            buffer.removeFirst()
        }
    }

    private mutating func nextSentence() -> String? {
        trimLeadingWhitespace()
        guard !buffer.isEmpty else { return nil }
        if atLineStart {
            if buffer.hasPrefix(Self.marker) {
                stopped = true
                buffer = ""
                return nil
            }
            // Could still become the marker once more tokens arrive.
            if Self.marker.hasPrefix(buffer) { return nil }
            atLineStart = false
        }
        guard let end = sentenceEnd() else { return nil }
        let sentence = String(buffer[..<end]).trimmingCharacters(in: .whitespaces)
        buffer.removeSubrange(..<end)
        return sentence.isEmpty ? nil : sentence
    }

    private func sentenceEnd() -> String.Index? {
        var index = buffer.startIndex
        while index < buffer.endIndex {
            let char = buffer[index]
            if char.isNewline { return index }
            if Self.terminators.contains(char) {
                var end = buffer.index(after: index)
                while end < buffer.endIndex, Self.terminators.contains(buffer[end]) || Self.closers.contains(buffer[end]) {
                    end = buffer.index(after: end)
                }
                // Without a following character we cannot tell "4." from "4.50" yet.
                guard end < buffer.endIndex else { return nil }
                if buffer[end].isWhitespace && !(char == "." && isAbbreviation(before: index)) { return end }
                index = end
                continue
            }
            index = buffer.index(after: index)
        }
        return nil
    }

    private func isAbbreviation(before dot: String.Index) -> Bool {
        let word = buffer[..<dot].reversed().prefix { !$0.isWhitespace && !"¿¡(\"".contains($0) }
        return Self.abbreviations.contains(String(word.reversed()).lowercased())
    }
}
