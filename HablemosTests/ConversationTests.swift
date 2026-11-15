import HablemosCore
import Testing
@testable import Hablemos

@MainActor
struct ConversationTests {
    @Test func explicitStyleShowsCorrectionCardBeforeReply() async {
        let model = ConversationViewModel(style: .explicit)
        model.beginListening()
        try? await Task.sleep(for: .seconds(1.5))
        await model.endListening()

        let kinds = model.items.map { item -> String in
            switch item {
            case .lucia: "lucia"
            case .user: "user"
            case .correction: "correction"
            case .retryCard: "retry"
            case .recastNote: "recast"
            }
        }
        #expect(kinds == ["lucia", "user", "correction", "lucia"])
    }

    @Test func promptStyleAddsRetryCard() async {
        let model = ConversationViewModel(style: .prompt)
        model.beginListening()
        try? await Task.sleep(for: .seconds(1.5))
        await model.endListening()
        guard case .retryCard? = model.items.last else {
            Issue.record("expected a retry card last")
            return
        }
    }
}
