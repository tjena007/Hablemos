import HablemosCore
import SwiftUI

@MainActor
@Observable
final class WarmupViewModel {
    enum Kind { case review, word, sentence }

    struct Step {
        let kind: Kind
        let item: WarmupItem
    }

    private static let missesBeforeSkip = 2

    let steps: [Step]
    private(set) var index = 0
    private(set) var heard: String?
    private(set) var progress: PhraseProgress
    private(set) var misses = 0
    private(set) var isListening = false

    private let stt: SpeechToText
    private let locale: Locale
    private var listenTask: Task<String, Never>?
    private var silenceTask: Task<Void, Never>?
    private var stopping: Task<Void, Never>?
    private var attempt: UUID?

    init(warmup: Warmup, review: [WarmupItem], stt: SpeechToText, locale: Locale) {
        steps = review.map { Step(kind: .review, item: $0) } + warmup.words.map { Step(kind: .word, item: $0) } + warmup.sentences.map { Step(kind: .sentence, item: $0) }
        self.stt = stt
        self.locale = locale
        progress = PhraseMatcher.progress(heard: [], target: steps[0].item.spanish)
    }

    var step: Step { steps[index] }
    var isLast: Bool { index == steps.count - 1 }
    var isCorrect: Bool { heard != nil && progress.isComplete }
    var canAdvance: Bool { isCorrect || misses >= Self.missesBeforeSkip }

    var positionInKind: (number: Int, total: Int) {
        let sameKind = steps.filter { $0.kind == step.kind }.count
        let before = steps[..<index].filter { $0.kind == step.kind }.count
        return (before + 1, sameKind)
    }

    func toggleListening() {
        if isListening {
            Task { await endListening() }
        } else {
            beginListening()
        }
    }

    /// Grades every partial transcript and stops by itself once every word is heard, or after a
    /// silence that shortens as the phrase nears completion.
    func beginListening() {
        guard !isListening else { return }
        isListening = true
        heard = nil
        let target = step.item.spanish
        progress = PhraseMatcher.progress(heard: [], target: target)
        let attempt = UUID()
        self.attempt = attempt
        let previousStop = stopping
        listenTask = Task {
            var text = ""
            // The recognizer may still be finalizing the last attempt; starting over it would cut this one off.
            await previousStop?.value
            guard self.attempt == attempt else { return text }
            for await update in stt.startListening(locale: locale) {
                // A cancelled attempt's late results must not grade the next one.
                guard self.attempt == attempt else { break }
                let changed = update.text != text
                if changed {
                    text = update.text
                    progress = PhraseMatcher.progress(heard: [update.text] + update.alternatives, target: target, previous: progress)
                }
                // Once stopping, only collect the final text; a timer armed now would cut the next attempt short.
                guard isListening else { continue }
                if progress.isComplete {
                    // Every word is in, so grade now, like Duolingo; the recognizer finalizes in the background.
                    heard = text
                    cancelListening()
                } else if changed || silenceTask == nil {
                    restartSilenceTimer()
                }
            }
            // The stream can end on its own (mic permission denied, unsupported locale).
            if isListening, self.attempt == attempt { Task { await endListening() } }
            return text
        }
    }

    /// Waits for the recognizer's final pass, which often catches short words the live results missed.
    func endListening() async {
        guard isListening, let listenTask else { return }
        let attempt = attempt
        isListening = false
        silenceTask?.cancel()
        silenceTask = nil
        let stop = Task { await stt.stopListening() }
        stopping = stop
        await stop.value
        let text = await listenTask.value
        guard self.attempt == attempt else { return }
        heard = text
        if !isCorrect { misses += 1 }
    }

    /// Abandons the current attempt without grading it.
    func cancelListening() {
        guard isListening else { return }
        isListening = false
        attempt = nil
        silenceTask?.cancel()
        silenceTask = nil
        listenTask = nil
        stopping = Task { await stt.stopListening() }
    }

    /// Duolingo's timeout: 5 s with nothing heard, down to 1 s when the phrase is almost done.
    private func restartSilenceTimer() {
        silenceTask?.cancel()
        let delay = max(5 * (1 - progress.fraction), 1)
        silenceTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await endListening()
        }
    }

    /// Returns true once the last step is done.
    func advance() -> Bool {
        cancelListening()
        guard !isLast else { return true }
        index += 1
        heard = nil
        misses = 0
        progress = PhraseMatcher.progress(heard: [], target: step.item.spanish)
        return false
    }
}

struct WarmupView: View {
    let onFinish: () -> Void
    let onClose: () -> Void
    @State private var model: WarmupViewModel
    @Environment(SpeechPlayer.self) private var player

    init(scenario: ScenarioConfig, review: [WarmupItem], stt: SpeechToText, locale: Locale, onFinish: @escaping () -> Void, onClose: @escaping () -> Void) {
        _model = State(initialValue: WarmupViewModel(warmup: Warmup.forScenario(scenario.id), review: review, stt: stt, locale: locale))
        self.onFinish = onFinish
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(title: headerTitle, subtitle: headerSubtitle, onLeading: onClose) { EmptyView() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SegmentProgress(total: model.steps.count, filled: model.index + 1)
                        .animation(.hablemos, value: model.index)
                    promptCard
                        .id(model.index)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    if let heard = model.heard {
                        resultCard(heard: heard)
                            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96)))
                    }
                }
                .animation(.hablemos, value: model.index)
                .animation(.hablemos, value: model.heard)
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            BottomActionBar(caption: caption) {
                EmptyView()
            } center: {
                TapToTalkButton(isListening: model.isListening) {
                    player.stop()
                    model.toggleListening()
                }
            } trailing: {
                EmptyView()
            }
            if model.canAdvance {
                PrimaryButton(title: model.isLast ? "Start talking" : "Next") {
                    if model.advance() { onFinish() }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .task(id: model.index) { player.say(model.step.item.spanish.replacingOccurrences(of: "…", with: "")) }
        .onDisappear { model.cancelListening() }
        .sensoryFeedback(.impact(weight: .light), trigger: model.isListening)
        .sensoryFeedback(trigger: model.heard) { _, heard in
            heard == nil ? nil : (model.isCorrect ? .success : .warning)
        }
    }

    private var headerTitle: String {
        switch model.step.kind {
        case .review: "Say it again"
        case .word: "Words first"
        case .sentence: "Now in sentences"
        }
    }

    private var headerSubtitle: String {
        let position = model.positionInKind
        let noun = switch model.step.kind {
        case .review: "phrases"
        case .word: "words"
        case .sentence: "sentences"
        }
        return "Warm-up · \(position.number) of \(position.total) \(noun)"
    }

    private var promptLabel: String {
        switch model.step.kind {
        case .review: "Say it the right way"
        case .word: "Say this word"
        case .sentence: "Say this sentence"
        }
    }

    private var caption: String {
        if model.isListening { return "Listening… stops when you're done" }
        return "Tap the mic and say it"
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            UpperLabel(text: promptLabel)
            Text(highlightedTarget)
                .font(.display(model.step.kind == .word ? 32 : 24))
                .lineSpacing(4)
                .animation(.easeOut(duration: 0.15), value: model.progress)
                .accessibilityLabel(model.step.item.spanish)
            Text(model.step.item.english)
                .font(.subheadline)
                .foregroundStyle(Noche.textMuted)
            HStack(spacing: 10) {
                // The open mic would hear Lucía and pass the step.
                PlayCircle(size: 36) { player.say(model.step.item.spanish) }
                    .disabled(model.isListening)
                Text("Hear Lucía say it")
                    .font(.footnote)
                    .foregroundStyle(Noche.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18, padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
    }

    /// Target words turn mint as the recognizer hears them.
    private var highlightedTarget: AttributedString {
        var result = AttributedString()
        for (offset, word) in model.progress.words.enumerated() {
            var piece = AttributedString((offset == 0 ? "" : " ") + word)
            piece.foregroundColor = model.progress.recognized[offset] ? Noche.mint : Noche.text
            result += piece
        }
        return result
    }

    private func resultCard(heard: String) -> some View {
        let isCorrect = model.isCorrect
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                UpperLabel(text: "You said", color: isCorrect ? Noche.mint : Noche.missText)
                Spacer()
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(isCorrect ? Noche.mint : Noche.missText)
                    .symbolEffect(.bounce, value: heard)
                    .accessibilityHidden(true)
                Text(isCorrect ? "Correct" : "Not quite")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isCorrect ? Noche.mint : Noche.missText)
            }
            Text(heard.isEmpty ? "Didn't catch that. Try again." : heard)
                .font(.title3)
                .foregroundStyle(isCorrect ? Noche.text : Noche.missSoft)
            if !isCorrect, !heard.isEmpty {
                Text("Missed: \(model.progress.missedWords.joined(separator: " "))")
                    .font(.footnote)
                    .foregroundStyle(Noche.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(
            fill: isCorrect ? Noche.surfaceMint : Noche.missSurface,
            border: isCorrect ? .clear : Noche.missBorder,
            borderWidth: isCorrect ? 0 : 1,
            radius: 18,
            padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        )
    }
}
