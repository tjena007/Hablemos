import Foundation
import HablemosCore
import Testing
@testable import Hablemos

@MainActor
struct WarmupViewModelTests {
    private func makeModel(saying text: String) -> WarmupViewModel {
        WarmupViewModel(warmup: Warmup.forScenario("cafe"), review: [], stt: MockSpeechToText(scripted: [text]), locale: Locale(identifier: "es-MX"))
    }

    @Test func stopsByItselfOnceEveryWordIsHeard() async {
        let model = makeModel(saying: "un café")
        model.beginListening()
        for _ in 0..<40 where model.isListening { try? await Task.sleep(for: .milliseconds(50)) }
        #expect(!model.isListening)
        #expect(model.isCorrect)
        #expect(model.misses == 0)
    }

    @Test func manualStopOnWrongAnswerCountsAMiss() async {
        let model = makeModel(saying: "una casa")
        model.beginListening()
        try? await Task.sleep(for: .milliseconds(500))
        await model.endListening()
        #expect(!model.isCorrect)
        #expect(model.misses == 1)
        #expect(model.progress.missedWords == ["un", "café"])
    }

    @Test func advancingMidAttemptDoesNotGradeTheNextStep() async {
        let model = makeModel(saying: "un cruasán")  // the second step's phrase
        model.beginListening()
        _ = model.advance()
        try? await Task.sleep(for: .milliseconds(600))
        #expect(!model.isListening)
        #expect(model.heard == nil)
        #expect(model.progress.fraction == 0)
    }
}
