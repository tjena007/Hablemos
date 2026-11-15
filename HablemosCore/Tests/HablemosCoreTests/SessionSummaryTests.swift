import Foundation
import Testing
@testable import HablemosCore

struct SessionSummaryTests {
    static let json = """
    {"mistakes":[{"original":"es rico","corrected":"está rico","category":"ser_vs_estar","explanation":"Use estar."}],"newWords":["cortado"],"estimatedLevel":"A2"}
    """
    let expected = SessionSummary(
        mistakes: [MistakeEntry(original: "es rico", corrected: "está rico", category: "ser_vs_estar", explanation: "Use estar.")],
        newWords: ["cortado"], estimatedLevel: .a2)

    @Test func parsesValid() throws {
        #expect(try SessionSummaryParser.parse(Self.json) == expected)
    }

    @Test func parsesFenced() throws {
        #expect(try SessionSummaryParser.parse("```json\n\(Self.json)\n```") == expected)
    }

    @Test func parsesProseWrappedWithBracesInStrings() throws {
        let raw = "Here you go: {\"mistakes\":[],\"newWords\":[\"a}b\"],\"estimatedLevel\":\"B1\"} Hope it helps {x}"
        let summary = try SessionSummaryParser.parse(raw)
        #expect(summary.newWords == ["a}b"])
        #expect(summary.estimatedLevel == .b1)
    }

    @Test func invalidLevelThrows() {
        let raw = Self.json.replacingOccurrences(of: "A2", with: "C2")
        #expect(throws: SessionSummaryError.invalidLevel("C2")) { try SessionSummaryParser.parse(raw) }
    }

    @Test func missingFieldThrows() {
        #expect(throws: SessionSummaryError.self) { try SessionSummaryParser.parse("{\"mistakes\":[],\"estimatedLevel\":\"A1\"}") }
    }

    @Test func emptyStringThrows() {
        let raw = Self.json.replacingOccurrences(of: "Use estar.", with: " ")
        #expect(throws: SessionSummaryError.emptyField("mistakes.explanation")) { try SessionSummaryParser.parse(raw) }
    }

    @Test func noObjectThrows() {
        #expect(throws: SessionSummaryError.noJSONObject) { try SessionSummaryParser.parse("sorry, no") }
    }

    @Test func schemaIsValidJSONAndPromptIncludesTranscript() throws {
        _ = try JSONSerialization.jsonObject(with: Data(SessionSummary.jsonSchema.utf8))
        let prompt = SessionSummaryPrompt.make(transcript: [ChatMessage(role: .user, text: "Hola"), ChatMessage(role: .tutor, text: "¿Qué tal?")])
        #expect(prompt.contains("Learner: Hola"))
        #expect(prompt.contains("Tutor: ¿Qué tal?"))
        #expect(prompt.contains("ONLY one strict JSON object"))
    }
}
