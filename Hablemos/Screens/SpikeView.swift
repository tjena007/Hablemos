import SwiftUI

struct SpikeView: View {
    let host: LiteRTEngineHost
    let onClose: () -> Void
    @State private var model: SpikeViewModel
    @State private var variant = ModelVariant.e4b

    init(host: LiteRTEngineHost, onClose: @escaping () -> Void) {
        self.host = host
        self.onClose = onClose
        _model = State(initialValue: SpikeViewModel(host: host))
    }

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(title: "Model spike", subtitle: "Gemma 4 · LiteRT-LM · Metal GPU", onLeading: onClose) { EmptyView() }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Model", selection: $variant) {
                        ForEach(ModelVariant.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    ForEach(Array(model.log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Noche.textSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            PrimaryButton(title: model.isRunning ? "Running…" : "Run spike") {
                Task { await model.run(variant: variant) }
            }
            .disabled(model.isRunning)
            .padding(20)
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-autoSpike") { await model.run(variant: variant) }
        }
    }
}
