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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Noche.bg.ignoresSafeArea()
            Group {
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
            }
            .id(model.route)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            if showIntro {
                IntroView { showIntro = false }
                    .transition(.opacity)
            }
        }
        .animation(.hablemos, value: model.route)
        .foregroundStyle(Noche.text)
        .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
