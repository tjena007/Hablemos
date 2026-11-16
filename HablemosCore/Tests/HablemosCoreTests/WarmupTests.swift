import Testing
@testable import HablemosCore

struct WarmupTests {
    @Test func everyScenarioHasWordsAndSentences() {
        for scenario in LevelsConfig.default.scenarios {
            let warmup = Warmup.forScenario(scenario.id)
            #expect(!warmup.words.isEmpty, "\(scenario.id) has no words")
            #expect(!warmup.sentences.isEmpty, "\(scenario.id) has no sentences")
        }
    }

    @Test func promptListsFocusWordsOnlyWhenGiven() {
        let level = LevelsConfig.default.levels[0]
        let cafe = LevelsConfig.default.scenarios[0]
        #expect(PromptBuilder.systemPrompt(level: level, scenario: cafe, focusWords: ["un café"]).contains("un café"))
        #expect(!PromptBuilder.systemPrompt(level: level, scenario: cafe).contains("just practiced"))
        #expect(PromptBuilder.systemPrompt(level: level, scenario: cafe, focusWords: ["un café"]).contains("at most one new word"))
    }
}
