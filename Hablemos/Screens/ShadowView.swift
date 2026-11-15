import SwiftUI

struct ShadowView: View {
    let text: String
    let translation: String?
    let onClose: () -> Void
    @State private var speed = 0.9
    @State private var isPlaying = false
    @State private var progress = 0.0
    @State private var listenOnly = false
    @State private var hideText = false
    @State private var playbackTask: Task<Void, Never>?
    @Environment(SpeechPlayer.self) private var player

    var body: some View {
        ZStack {
            Noche.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                StepHeader(
                    title: "Shadow",
                    subtitle: "Lucía's latest line",
                    leadingIcon: "xmark",
                    leadingLabel: "Close",
                    onLeading: onClose
                ) { EmptyView() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        lineBlock
                        waveformCard
                        Text("Play it, then say it along with Lucía. Slow it down if you need to.")
                            .font(.subheadline)
                            .foregroundStyle(Noche.textSoft)
                        HStack {
                            Text("Speed").font(.footnote).foregroundStyle(Noche.textMuted)
                            SpeedSegmentedControl(options: [0.75, 0.9, 1], selection: $speed)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                BottomActionBar(caption: "Speak along with her") {
                    OutlinePill(title: "Listen only", isOn: listenOnly) { listenOnly.toggle() }
                } center: {
                    PlayToggleButton(isPlaying: isPlaying, action: togglePlayback)
                } trailing: {
                    OutlinePill(title: "Hide text", isOn: hideText) { hideText.toggle() }
                }
            }
        }
        .onDisappear {
            playbackTask?.cancel()
            player.stop()
        }
    }

    private var lineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.display(28, relativeTo: .title))
                .tracking(-0.3)
                .lineSpacing(6)
                .opacity(hideText ? 0.08 : 1)
                .accessibilityLabel(hideText ? "Line hidden" : text)
            if let translation { Text(translation).font(.subheadline).foregroundStyle(Noche.textMuted) }
        }
    }

    private var waveformCard: some View {
        VStack(spacing: 12) {
            waveformRow("Lucía", heights: Self.bars, color: Noche.mint)
        }
        .card(radius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
    }

    private func waveformRow(_ label: String, heights: [CGFloat], color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(Noche.textMuted).frame(width: 44, alignment: .leading)
            WaveformBars(heights: heights, color: color, progress: isPlaying || progress > 0 ? progress : 1)
        }
    }

    private static let bars: [CGFloat] = (0..<40).map { 6 + CGFloat(abs(sin(Double($0) * 0.7)) * 22) }

    private func togglePlayback() {
        if isPlaying {
            playbackTask?.cancel()
            player.stop()
            isPlaying = false
            return
        }
        isPlaying = true
        progress = 0
        let duration = max(2, Double(text.split(separator: " ").count) * 0.45) / speed
        player.say(text, rate: Float(0.5 * speed))
        playbackTask = Task {
            let steps = 60
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(duration / Double(steps)))
                if Task.isCancelled { return }
                progress = Double(step) / Double(steps)
            }
            isPlaying = false
        }
    }
}
