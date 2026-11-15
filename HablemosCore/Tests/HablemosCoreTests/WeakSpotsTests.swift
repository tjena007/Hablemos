import Foundation
import Testing
@testable import HablemosCore

struct WeakSpotsTests {
    func entry(_ category: String, _ original: String = "x") -> MistakeEntry {
        MistakeEntry(original: original, corrected: "y", category: category, explanation: "e")
    }
    let day1 = Date(timeIntervalSince1970: 1_000_000)
    let day2 = Date(timeIntervalSince1970: 2_000_000)

    @Test func sortsByCountThenRecency() {
        var tally = MistakeTally()
        tally.record([entry("ser_vs_estar"), entry("gender"), entry("gender")], on: day1)
        tally.record([entry("por_vs_para")], on: day2)
        let top = tally.top()
        #expect(top.map(\.category) == ["gender", "por_vs_para", "ser_vs_estar"])
        #expect(top[0].count == 2)
    }

    @Test func keepsFirstExampleAndLatestDate() {
        var tally = MistakeTally()
        tally.record([entry("gender", "first")], on: day2)
        tally.record([entry("gender", "second")], on: day1)
        let spot = tally.top(1)[0]
        #expect(spot.example.original == "first")
        #expect(spot.lastSeen == day2)
    }

    @Test func limitsToN() {
        var tally = MistakeTally()
        tally.record(["a", "b", "c", "d"].map { entry($0) }, on: day1)
        #expect(tally.top().count == 3)
        #expect(tally.top(1).count == 1)
    }

    @Test func displayNameReplacesUnderscores() {
        #expect(MistakeTally.displayName(for: "ser_vs_estar") == "ser vs estar")
    }

    @Test func roundTripsThroughJSON() throws {
        var tally = MistakeTally()
        tally.record([entry("gender")], on: day1)
        let decoded = try JSONDecoder().decode(MistakeTally.self, from: JSONEncoder().encode(tally))
        #expect(decoded == tally)
    }
}
