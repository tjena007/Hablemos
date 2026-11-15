import HablemosCore
import SwiftData
import SwiftUI

@main
struct HablemosApp: App {
    @State private var model = AppModel()
    @State private var player = SpeechPlayer(tts: AVSpeechTextToSpeech())
    private let container: ModelContainer

    init() {
        do {
            container = try PersistenceSchema.makeContainer()
        } catch {
            fatalError("Could not open the progress database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .environment(player)
                .modelContainer(container)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.modelContext) private var modelContext
    @State private var showIntro = !ProcessInfo.processInfo.arguments.contains("-autoSpike")

    var body: some View {
        ZStack {
            Noche.bg.ignoresSafeArea()
            switch model.route {
            case .home: HomeView(model: model)
            case .modelSetup: ModelSetupView(onReady: { model.startWarmup(context: modelContext) })
            case .warmup:
                if let scenario = model.warmupScenario {
                    WarmupView(
                        scenario: scenario,
                        review: model.warmupReview,
                        stt: model.makeWarmupSTT(scripted: (model.warmupReview.map(\.spanish) + Warmup.forScenario(scenario.id).spokenTargets)),
                        locale: model.warmupLocale,
                        onFinish: { model.startConversation(context: modelContext) },
                        onClose: { model.go(.home) }
                    )
                }
            case .conversation: ConversationView(setup: model.setup, onEnd: { model.finish(with: $0) })
            case .spike: SpikeView(host: model.engineHost, onClose: { model.go(.home) })
            case .summary: SummaryView(result: model.result ?? .demo, onRoundTwo: { model.startConversation(context: modelContext) }, onDone: { model.go(.home) })
            }
            if showIntro {
                IntroView { showIntro = false }
                    .transition(.opacity)
            }
        }
        .foregroundStyle(Noche.text)
        .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
