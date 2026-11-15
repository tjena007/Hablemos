import Foundation
import Testing
@testable import HablemosCore

struct LevelsConfigTests {
    @Test func defaultCoversEveryLevelWithScenarios() {
        let config = LevelsConfig.default
        for level in CEFRLevel.allCases {
            #expect(config.config(for: level) != nil)
            #expect(!config.scenarios(for: level).isEmpty)
        }
        #expect(config.config(for: .a1)?.ttsRate == 0.38)
        #expect(config.config(for: .a1)?.englishHelp == .allowed)
        #expect(config.config(for: .b1)?.englishHelp == .discouraged)
        #expect(config.config(for: .b2)?.englishHelp == LevelConfig.EnglishHelp.none)
        #expect(config.scenarios(for: .a1).map(\.title) == ["En el café", "Preséntate"])
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(LevelsConfig.default)
        #expect(try LevelsConfig.load(from: data) == LevelsConfig.default)
    }

    @Test func loadsHandWrittenJSON() throws {
        let json = """
        {"levels":[{"level":"A1","maxSentences":2,"grammarScope":"present","ttsRate":0.4,"englishHelp":"none","note":"n"}],
         "scenarios":[{"id":"x","title":"T","subtitle":"S","level":"A1","description":"d"}]}
        """
        let config = try LevelsConfig.load(from: Data(json.utf8))
        #expect(config.levels.first?.englishHelp == LevelConfig.EnglishHelp.none)
        #expect(config.scenarios.first?.id == "x")
    }

    @Test func invalidJSONThrows() {
        #expect(throws: DecodingError.self) { try LevelsConfig.load(from: Data("{}".utf8)) }
    }
}
