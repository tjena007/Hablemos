import Foundation
import HablemosCore
import SwiftData
import Testing
@testable import Hablemos

@MainActor
struct ReviewItemsTests {
    private static var containers: [ModelContainer] = []

    @Test func reviewItemsComeFromSavedCorrectionsNewestFirstWithoutDuplicates() throws {
        let container = try PersistenceSchema.makeContainer(inMemory: true)
        Self.containers.append(container)
        let context = container.mainContext
        let store = ProgressStore(context: context)
        let metrics = SessionMetrics(turns: 2, wordsPerTurn: 5, errorsPerTurn: 1, englishSwitches: 0, averagePauseSeconds: 1)
        func correction(_ wrong: String, _ right: String, at date: Date) -> TurnRecord {
            TurnRecord(roleRaw: Turn.correctionRole, text: right, correction: Correction(wrong: wrong, right: right, explanation: "why"), timestamp: date)
        }
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        try store.record(date: old, scenarioID: "cafe", level: .a1, durationSeconds: 60, metrics: metrics,
                         turns: [correction("una café", "un café", at: old), TurnRecord(roleRaw: "user", text: "hola", correction: nil, timestamp: old)])
        try store.record(date: old.addingTimeInterval(86400), scenarioID: "cafe", level: .a1, durationSeconds: 60, metrics: metrics,
                         turns: [correction("es rico", "está rico", at: old.addingTimeInterval(86400)), correction("una café", "Un café", at: old.addingTimeInterval(86401))])

        let items = try AppModel.reviewItems(context: context)

        #expect(items.map(\.spanish) == ["Un café", "está rico"])
    }
}
