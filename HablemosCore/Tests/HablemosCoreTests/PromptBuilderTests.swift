import Foundation
import Testing
@testable import HablemosCore

struct PromptBuilderTests {
    let a1 = LevelsConfig.default.config(for: .a1)!
    let cafe = LevelsConfig.default.scenarios[0]

    @Test func includesLevelScenarioAndRules() {
        let prompt = PromptBuilder.systemPrompt(level: a1, scenario: cafe)
        #expect(prompt.hasPrefix("You are Lucía, a friendly barista in Madrid"))
        #expect(prompt.contains("Learner level: A1. Scenario: \(cafe.description)."))
        #expect(prompt.contains("Reply ONLY in Spanish, 2 short sentences max, using present tense only."))
        #expect(prompt.contains("CORRECTION: <wrong phrase> => <correct phrase> | <one short English explanation>"))
    }

    @Test func weakSpotsCappedAtThree() {
        let prompt = PromptBuilder.systemPrompt(level: a1, scenario: cafe, weakSpots: ["ser vs estar", "por vs para", "gender", "ignored"])
        #expect(prompt.contains("Naturally create chances to practice: ser vs estar, por vs para, gender."))
        #expect(!prompt.contains("ignored"))
    }

    @Test func noWeakSpotsOmitsLine() {
        #expect(!PromptBuilder.systemPrompt(level: a1, scenario: cafe).contains("Naturally create chances"))
    }

    @Test func historyKeepsLastMessagesAndPrefixesSummary() {
        let turns = (0..<20).map { ChatMessage(role: $0 % 2 == 0 ? .user : .tutor, text: "m\($0)") }
        let history = PromptBuilder.buildHistory(turns: turns, summary: "ordered coffee")
        #expect(history.count == 17)
        #expect(history[0].text == "Earlier in this conversation: ordered coffee")
        #expect(history[1].text == "m4")
        #expect(history.last?.text == "m19")
    }

    @Test func shortHistoryIsUnchanged() {
        let turns = [ChatMessage(role: .user, text: "hola")]
        #expect(PromptBuilder.buildHistory(turns: turns, summary: "x") == turns)
    }

    @Test func missingSummaryJustTruncates() {
        let turns = (0..<20).map { ChatMessage(role: .user, text: "m\($0)") }
        #expect(PromptBuilder.buildHistory(turns: turns, summary: nil, keepLast: 4).map(\.text) == ["m16", "m17", "m18", "m19"])
    }
}
