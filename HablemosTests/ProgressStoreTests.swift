import Foundation
import HablemosCore
import SwiftData
import Testing
@testable import Hablemos

@MainActor
struct ProgressStoreTests {
    private static let strong = SessionMetrics(turns: 5, wordsPerTurn: 10, errorsPerTurn: 1, englishSwitches: 0, averagePauseSeconds: 1)
    private static let weak = SessionMetrics(turns: 5, wordsPerTurn: 3, errorsPerTurn: 4, englishSwitches: 2, averagePauseSeconds: 3)

    // Containers must outlive their contexts or SwiftData traps.
    private static var containers: [ModelContainer] = []

    private func makeStore() throws -> ProgressStore {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let container = try PersistenceSchema.makeContainer(inMemory: true)
        Self.containers.append(container)
        return ProgressStore(context: container.mainContext, calendar: calendar)
    }

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 - 1_700_000_000.truncatingRemainder(dividingBy: 86400))
            .addingTimeInterval(Double(offset) * 86400 + Double(hour) * 3600)
    }

    @discardableResult
    private func record(_ store: ProgressStore, _ metrics: SessionMetrics, on date: Date) throws -> PracticeSession {
        try store.record(
            date: date, scenarioID: "cafe", level: .a1, durationSeconds: 120, metrics: metrics,
            turns: [
                TurnRecord(roleRaw: "user", text: "Quiero un cafe", correction: Correction(wrong: "un cafe", right: "un café", explanation: "accent"), timestamp: date),
                TurnRecord(roleRaw: "lucia", text: "Claro", correction: nil, timestamp: date.addingTimeInterval(1)),
            ],
            mistakes: [MistakeRecord(category: "accent", example: "cafe")],
            vocab: ["un café"]
        )
    }

    @Test func threeStrongSessionsUnlockNextLevel() throws {
        let store = try makeStore()
        try record(store, Self.strong, on: day(0))
        try record(store, Self.strong, on: day(0, hour: 15))
        #expect(try store.profile().strongSessionStreak == 2)
        #expect(try store.profile().level == .a1)

        try record(store, Self.strong, on: day(0, hour: 18))
        #expect(try store.profile().level == .a2)
        #expect(try store.profile().strongSessionStreak == 0)

        try record(store, Self.strong, on: day(0, hour: 19))
        try record(store, Self.weak, on: day(0, hour: 20))
        #expect(try store.profile().strongSessionStreak == 0)
        #expect(try store.profile().level == .a2)
    }

    @Test func recordUpdatesMistakesAndVocab() throws {
        let store = try makeStore()
        try record(store, Self.strong, on: day(0))
        try record(store, Self.strong, on: day(1))
        let mistakes = try store.context.fetch(FetchDescriptor<MistakeStat>())
        let vocab = try store.context.fetch(FetchDescriptor<VocabItem>())
        #expect(mistakes.count == 1 && mistakes[0].count == 2)
        #expect(vocab.count == 1 && vocab[0].timesUsed == 2)
        let sessions = try store.context.fetch(FetchDescriptor<PracticeSession>())
        #expect(sessions.allSatisfy { $0.turns?.count == 2 })
    }

    @Test func dayStreakRules() throws {
        let store = try makeStore()
        try record(store, Self.weak, on: day(0))
        #expect(try store.profile().dayStreak == 1)
        try record(store, Self.weak, on: day(0, hour: 20))
        #expect(try store.profile().dayStreak == 1)
        try record(store, Self.weak, on: day(1))
        #expect(try store.profile().dayStreak == 2)
        try record(store, Self.weak, on: day(2))
        #expect(try store.profile().dayStreak == 3)
        try record(store, Self.weak, on: day(5))
        #expect(try store.profile().dayStreak == 1)
    }

    @Test func exportImportRoundTrip() throws {
        let source = try makeStore()
        for offset in 0..<3 { try record(source, Self.strong, on: day(offset)) }
        let profile = try source.profile()
        profile.voiceIdentifier = "voice.x"
        profile.ttsRateOverride = 0.4
        profile.useE2BModel = true
        let exported = try source.exportData()
        #expect(String(decoding: exported, as: UTF8.self).contains("\"version\" : 1"))

        let target = try makeStore()
        try target.importData(exported, replacing: true)
        let restored = try target.profile()
        #expect(restored.level == .a2)
        #expect(restored.dayStreak == 3)
        #expect(restored.voiceIdentifier == "voice.x")
        #expect(restored.ttsRateOverride == 0.4)
        #expect(restored.useE2BModel)
        let sessions = try target.context.fetch(FetchDescriptor<PracticeSession>())
        #expect(sessions.count == 3)
        #expect(try sessions.first?.metrics == Self.strong)
        #expect(sessions.allSatisfy { $0.turns?.count == 2 })
        #expect(try target.context.fetch(FetchDescriptor<MistakeStat>()).first?.count == 3)
        #expect(try target.exportData() == exported)

        try target.importData(exported, replacing: false)
        #expect(try target.context.fetch(FetchDescriptor<PracticeSession>()).count == 3)
    }

    @Test func rejectsUnsupportedVersionAndGarbage() throws {
        let store = try makeStore()
        let exported = try store.exportData()
        let bumped = String(decoding: exported, as: UTF8.self).replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 99")
        #expect(throws: ProgressBackupError.unsupportedVersion(found: 99, supported: 1)) {
            try store.importData(Data(bumped.utf8), replacing: true)
        }
        #expect(throws: ProgressBackupError.self) {
            try store.importData(Data("nope".utf8), replacing: true)
        }
        #expect(throws: ProgressBackupError.self) {
            try store.importData(Data("{\"version\":1}".utf8), replacing: true)
        }
    }
}
