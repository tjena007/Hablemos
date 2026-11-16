import HablemosCore
import SwiftUI

struct ConversationView: View {
    let onEnd: (SessionResult) -> Void
    let onPause: () -> Void
    @State private var model: ConversationViewModel
    @State private var showShadow = false
    @State private var showHint = false
    @Environment(SpeechPlayer.self) private var player
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    init(style: FeedbackStyle = .explicit, setup: SessionSetup? = nil, onEnd: @escaping (SessionResult) -> Void, onPause: @escaping () -> Void = {}) {
        self.onEnd = onEnd
        self.onPause = onPause
        let setup = setup ?? SessionSetup(config: .demo, services: .mock)
        _model = State(initialValue: ConversationViewModel(style: style, config: setup.config, services: setup.services))
    }

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(title: model.scenario.title, subtitle: "Conversation with Lucía · \(model.levelName)", leadingLabel: "Pause", onLeading: pause) {
                Button(action: end) {
                    Text("Terminar")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Noche.surfaceHi, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            luciaStage
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.items) { item in
                            row(item, showChips: item.id == model.latestLucia?.id)
                                .id(item.id)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                        }
                    }
                    .padding(16)
                    .animation(.hablemos, value: model.items.count)
                }
                .onChange(of: model.items.count) {
                    if let last = model.items.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            controls
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.isListening)
        .task {
            model.speech = player
            await model.prepare()
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active { model.cancelGeneration() }
        }
        .overlay {
            if model.isPreparing || model.isFinishing {
                VStack(spacing: 12) {
                    ProgressView().tint(Noche.brand)
                    Text(model.isFinishing ? "Summarizing your session…" : "Waking up Lucía…")
                        .font(.subheadline)
                        .foregroundStyle(Noche.textSoft)
                }
                .padding(24)
                .background(Noche.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showShadow) {
            ShadowView(text: model.latestLucia?.text ?? "", translation: model.latestLucia.flatMap { model.translations[$0.id] }, onClose: { showShadow = false })
        }
        .sheet(isPresented: $showHint) {
            HintSheet(suggestions: model.latestLucia.flatMap { model.suggestions[$0.id] }, warmup: Warmup.forScenario(model.scenario.id))
        }
        .onChange(of: model.isConcluded && !player.isSpeaking) { _, done in
            if done { end() }
        }
    }

    @ViewBuilder
    private func row(_ item: ChatItem, showChips: Bool) -> some View {
        switch item {
        case .lucia(_, let text, let highlight):
            VStack(alignment: .leading, spacing: 8) {
                UpperLabel(text: "Lucía", color: Noche.mint)
                Text(highlighted(text, word: highlight, color: Noche.mint))
                    .font(.title3)
                    .lineSpacing(4)
                    .frame(maxWidth: 310, alignment: .leading)
                if let translation = model.translations[item.id] {
                    Text(translation).font(.subheadline).foregroundStyle(Noche.textMuted).frame(maxWidth: 310, alignment: .leading)
                }
                if showChips { actionChips }
            }
        case .user(_, let text, let errorWord):
            HStack {
                Spacer(minLength: 40)
                Text(underlined(text, word: errorWord))
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Noche.surfaceHi, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 6, topTrailingRadius: 18))
            }
        case .retryCard:
            HStack {
                Spacer(minLength: 40)
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(Noche.missAccent)
                        .frame(width: 40, height: 40)
                        .background(Noche.missSurface, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Try that line again").font(.subheadline.weight(.semibold)).foregroundStyle(Noche.missSoft)
                        Text("Hold the mic and fix it yourself").font(.footnote).foregroundStyle(Noche.missMuted)
                    }
                }
                .card(border: Noche.missBorder, radius: 14, padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .frame(maxWidth: 290)
            }
        case .correction(_, let correction):
            HStack {
                Spacer(minLength: 40)
                VStack(alignment: .leading, spacing: 6) {
                    UpperLabel(text: "Correction", color: Noche.missText)
                    Text("\(Text(correction.wrong).strikethrough()) → \(Text(correction.right).fontWeight(.bold))")
                        .font(.subheadline)
                        .foregroundStyle(Noche.missSoft)
                    if !correction.explanation.isEmpty {
                        Text(correction.explanation).font(.footnote).foregroundStyle(Noche.missMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(fill: Noche.missSurface, border: Noche.missBorder, radius: 14, padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .frame(maxWidth: 290)
            }
        case .recastNote:
            Text("Lucía rephrased one word · saved to review")
                .font(.caption)
                .foregroundStyle(Noche.textMuted)
                .frame(maxWidth: .infinity)
        }
    }

    private var mood: Orb.Mood {
        if model.isListening { return .listening }
        if player.isSpeaking { return .speaking }
        if model.isReplying || model.isPreparing { return .thinking }
        return .idle
    }

    private var moodLabel: String {
        switch mood {
        case .listening: "Listening"
        case .speaking: "Lucía is speaking"
        case .thinking: "Thinking…"
        case .idle: "Your turn"
        }
    }

    /// Lucía's orb reacts to the conversation: it pulses while she speaks and rings your voice while she listens.
    private var luciaStage: some View {
        VStack(spacing: 10) {
            Orb(size: 84, mood: mood, level: model.level)
            Text(moodLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(mood == .listening ? Noche.mint : Noche.textMuted)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: moodLabel)
            if !model.scenario.missions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.scenario.missions, id: \.self) { mission in
                            Chip(text: mission, foreground: Noche.textSoft, background: Noche.surfaceHi)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .accessibilityLabel("Your missions: \(model.scenario.missions.joined(separator: ", "))")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var actionChips: some View {
        HStack(spacing: 8) {
            Button { replay(rate: 0.45) } label: {
                Image(systemName: "speaker.wave.2").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Replay")
            chip("Slower") { replay(rate: 0.32) }
            chip("Shadow", tint: true) { showShadow = true }
            chip("Translate") { Task { await model.translateLatest() } }
        }
        .foregroundStyle(Noche.textSoft)
        .font(.footnote)
    }

    private func chip(_ title: String, tint: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(tint ? .semibold : .regular)
                .foregroundStyle(tint ? Noche.mint : Noche.textSoft)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(tint ? Noche.surfaceMint : Noche.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(tint ? Noche.micRing : Noche.border))
        }
        .buttonStyle(PressableStyle())
    }

    /// Back pauses without saving; Home then offers to resume the lesson. Only Terminar ends it.
    private func pause() {
        Task {
            await model.pause()
            onPause()
        }
    }

    private func end() {
        guard !model.isFinishing else { return }
        Task {
            do {
                let result = try await model.finish(store: ProgressStore(context: modelContext))
                onEnd(result)
            } catch {
                model.errorMessage = "Could not save the session: \(error)"
            }
        }
    }

    private func replay(rate: Float) {
        if let line = model.latestLucia { player.say(line.text, rate: rate) }
    }

    private var controls: some View {
        BottomActionBar(caption: caption) {
            OutlinePill(title: "Hint") {
                showHint = true
                Task { await model.suggestReplies() }
            }
            // One model call at a time: the hint waits until Lucía's reply is in.
            .disabled(model.isReplying)
        } center: {
            HoldToTalkButton(
                onPress: { model.beginListening() },
                onRelease: { Task { await model.endListening() } }
            )
        } trailing: {
            OutlinePill(title: "English") { Task { await model.translateLatest() } }
        }
    }

    private var caption: String {
        if model.isListening { return model.liveTranscript.isEmpty ? "Listening…" : model.liveTranscript }
        if model.isConcluded { return "Lucía is saying goodbye…" }
        if model.isReplying { return "Lucía is replying…" }
        return "Hold to talk"
    }

    private func underlined(_ text: String, word: String?) -> AttributedString {
        var attributed = AttributedString(text)
        if let word, let range = attributed.range(of: word) {
            attributed[range].underlineStyle = .single
            attributed[range].underlineColor = UIColor(Noche.missAccent)
        }
        return attributed
    }
}

#Preview("You fix it") { ConversationView(style: .prompt, onEnd: { _ in }).background(Noche.bg).preferredColorScheme(.dark).environment(SpeechPlayer(tts: MockTextToSpeech())) }
#Preview("Lucía rephrases") { ConversationView(style: .recast, onEnd: { _ in }).background(Noche.bg).preferredColorScheme(.dark).environment(SpeechPlayer(tts: MockTextToSpeech())) }
#Preview("Correction card") { ConversationView(style: .explicit, onEnd: { _ in }).background(Noche.bg).preferredColorScheme(.dark).environment(SpeechPlayer(tts: MockTextToSpeech())) }

private struct HintSheet: View {
    /// Replies to Lucía's latest line; nil while they're being written.
    let suggestions: [WarmupItem]?
    let warmup: Warmup
    @Environment(SpeechPlayer.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(text: "You could reply")
                if let suggestions {
                    ForEach(suggestions, id: \.spanish, content: phrase)
                } else {
                    HStack(spacing: 10) {
                        ProgressView().tint(Noche.brandText)
                        Text("Thinking of replies…").font(.footnote).foregroundStyle(Noche.textMuted)
                    }
                }
                SectionHeading(text: "Words from the warm-up")
                    .padding(.top, 8)
                ForEach(warmup.words, id: \.spanish, content: phrase)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Noche.bg)
        .presentationDetents([.medium, .large])
        .animation(.hablemos, value: suggestions)
    }

    private func phrase(_ item: WarmupItem) -> some View {
        HStack(spacing: 12) {
            PlayCircle(size: 36) { player.say(item.spanish) }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.spanish).font(.callout.weight(.medium))
                Text(item.english).font(.footnote).foregroundStyle(Noche.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
