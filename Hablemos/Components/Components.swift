import SwiftUI

extension View {
    func card(
        fill: Color = Noche.surface,
        border: Color = Noche.border,
        borderWidth: CGFloat = 1,
        radius: CGFloat = 16,
        padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    ) -> some View {
        self
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(border, lineWidth: borderWidth))
    }
}

struct UpperLabel: View {
    let text: String
    var color: Color = Noche.textMuted

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.4)
            .foregroundStyle(color)
    }
}

struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(Noche.text)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Chip: View {
    let text: String
    var foreground: Color = Noche.mint
    var background: Color = Noche.surfaceMint
    var border: Color? = nil

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
            .overlay { if let border { Capsule().strokeBorder(border) } }
    }
}

struct PrimaryButton: View {
    let title: String
    var height: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Noche.onBrand)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(Noche.brand, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    var height: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Noche.text)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(Noche.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Noche.border))
        }
        .buttonStyle(PressableStyle())
    }
}

struct OutlinePill: View {
    let title: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Noche.text)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(isOn ? Noche.surfaceSel : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(Noche.border))
        }
        .buttonStyle(PressableStyle())
    }
}

struct PlayCircle: View {
    var size: CGFloat = 36
    var fill: Color = Noche.brandSurface
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.38))
                .foregroundStyle(Noche.brandText)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Play")
    }
}

/// Wine while idle; teal with rings rippling out while it listens to you.
private struct MicCircle: View {
    let systemImage: String
    var isActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(isActive ? Noche.onMint : Noche.onBrand)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 84, height: 84)
            .background(isActive ? Noche.mint : Noche.brand, in: Circle())
            .background { if isActive && !reduceMotion { PulseRings(color: Noche.mint) } }
            .scaleEffect(isActive ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
            .padding(12)
    }
}

private struct PulseRings: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<2, id: \.self) { ring in
                    let phase = (time / 1.6 + Double(ring) / 2).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .fill(color.opacity(0.28 * (1 - phase)))
                        .scaleEffect(1 + phase * 0.6)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct HoldToTalkButton: View {
    var label = "Hold to talk"
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var isPressed = false

    var body: some View {
        MicCircle(systemImage: "mic.fill", isActive: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPress()
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease()
                    }
            )
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Toggle recording") {
                if isPressed { onRelease() } else { onPress() }
                isPressed.toggle()
            }
    }
}

struct TapToTalkButton: View {
    let isListening: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MicCircle(systemImage: isListening ? "stop.fill" : "mic.fill", isActive: isListening)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(isListening ? "Stop listening" : "Start talking")
    }
}

struct PlayToggleButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MicCircle(systemImage: isPlaying ? "pause.fill" : "play.fill", isActive: isPlaying)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(isPlaying ? "Stop" : "Play and record")
    }
}

struct BottomActionBar<Leading: View, Center: View, Trailing: View>: View {
    var caption: String?
    @ViewBuilder var leading: Leading
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                leading.frame(maxWidth: .infinity, alignment: .leading)
                center
                trailing.frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Noche.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Noche.bg)
        .overlay(alignment: .top) { Rectangle().fill(Noche.border).frame(height: 1) }
    }
}

struct StepHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    var leadingIcon = "chevron.left"
    var leadingLabel = "Back"
    let onLeading: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onLeading) {
                Image(systemName: leadingIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Noche.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(leadingLabel)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.display(18, relativeTo: .headline))
                    .foregroundStyle(Noche.text)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Noche.textMuted)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Noche.border).frame(height: 1) }
    }
}

struct SegmentProgress: View {
    let total: Int
    let filled: Int
    var height: CGFloat = 6
    var emptyColor: Color = Noche.surfaceSel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(index < filled ? Noche.brand : emptyColor)
                    .frame(height: height)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(filled) of \(total)")
    }
}

struct ThinProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Noche.surfaceHi)
                Rectangle().fill(Noche.brand).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 4)
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.display(22))
                .foregroundStyle(Noche.text)
            Text(label)
                .font(.caption)
                .foregroundStyle(Noche.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 14, padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        .accessibilityElement(children: .combine)
    }
}

struct WaveformBars: View {
    let heights: [CGFloat]
    let color: Color
    var progress: Double = 1

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(Double(index) / Double(heights.count) <= progress ? 1 : 0.35))
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

struct SpeedSegmentedControl: View {
    let options: [Double]
    @Binding var selection: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(format(option))
                        .font(.subheadline.weight(option == selection ? .semibold : .regular))
                        .foregroundStyle(option == selection ? Color.white : Noche.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(option == selection ? Noche.surfaceSel : .clear, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Noche.surfaceHi, in: RoundedRectangle(cornerRadius: 12))
    }

    private func format(_ value: Double) -> String {
        (value == 1 ? "1" : String(format: "%g", value)) + "×"
    }
}

struct CorrectionLine: View {
    let wrong: String
    let right: String
    var font: Font = .subheadline

    var body: some View {
        Text("\(Text(wrong).strikethrough().foregroundStyle(Noche.textMuted)) \(Text("→").foregroundStyle(Noche.textMuted)) \(Text(right).fontWeight(.bold).foregroundStyle(Noche.text))")
            .font(font)
    }
}

func highlighted(_ text: String, word: String?, color: Color) -> AttributedString {
    var attributed = AttributedString(text)
    guard let word, let range = attributed.range(of: word) else { return attributed }
    attributed[range].foregroundColor = color
    attributed[range].inlinePresentationIntent = .stronglyEmphasized
    return attributed
}

// MARK: Motion

extension Animation {
    /// Screens and sheets push in with this spring.
    static let hablemos = Animation.spring(response: 0.45, dampingFraction: 0.85)
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Content rises into place 50 ms apart when a screen appears; only fades with Reduce Motion.
private struct Entrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown || reduceMotion ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.05)) { isShown = true }
            }
    }
}

extension View {
    func entrance(_ index: Int) -> some View { modifier(Entrance(index: index)) }
}

/// Lucía. Breathes while idle, pulses while she speaks, and wears a teal ring that follows your voice while she listens.
struct Orb: View {
    enum Mood { case idle, listening, thinking, speaking }

    var size: CGFloat = 72
    var mood: Mood = .idle
    var level: Float = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0xF2B8C4), Color(hex: 0xC2546E), Noche.brand, Color(hex: 0x3E0A18)],
                    center: UnitPoint(x: 0.34, y: 0.3), startRadius: 0, endRadius: size * 0.75
                ))
                .overlay { if mood == .speaking && !reduceMotion { shimmer(at: time) } }
                .shadow(color: Noche.brand.opacity(mood == .speaking ? 0.6 : 0.35), radius: size * 0.33)
                .background { if mood == .speaking && !reduceMotion { glow(at: time) } }
                .scaleEffect(reduceMotion ? 1 : scale(at: time))
                .overlay {
                    if mood == .listening {
                        Circle()
                            .strokeBorder(Noche.mint, lineWidth: max(2, size * 0.04))
                            .scaleEffect(1.14 + CGFloat(min(level, 1)) * 0.22)
                            .animation(.easeOut(duration: 0.12), value: level)
                    }
                }
                .frame(width: size, height: size)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mood)
        .accessibilityHidden(true)
    }

    /// Two out-of-step waves, so the glow swells like a voice rather than a metronome.
    private func voice(at time: Double) -> Double {
        0.5 + 0.3 * sin(time * 2 * .pi / 0.9) + 0.2 * sin(time * 2 * .pi / 0.37)
    }

    private func glow(at time: Double) -> some View {
        let pulse = CGFloat(voice(at: time))
        return ZStack {
            Circle()
                .fill(Color(hex: 0xE07A93).opacity(0.35 + 0.25 * pulse))
                .blur(radius: size * 0.32)
                .scaleEffect(1.25 + 0.3 * pulse)
            Circle()
                .fill(AngularGradient(
                    colors: [Color(hex: 0xF2B8C4), .clear, Noche.brand, .clear, Color(hex: 0xF2B8C4)],
                    center: .center,
                    angle: .degrees(time * 50)
                ))
                .blur(radius: size * 0.14)
                .scaleEffect(1.15 + 0.12 * pulse)
                .opacity(0.85)
        }
        .allowsHitTesting(false)
    }

    /// A soft highlight that drifts across her surface while she talks.
    private func shimmer(at time: Double) -> some View {
        Circle()
            .fill(AngularGradient(
                colors: [.white.opacity(0.35), .clear, .clear, .white.opacity(0.15), .clear],
                center: .center,
                angle: .degrees(-time * 80)
            ))
            .blendMode(.plusLighter)
            .clipShape(Circle())
    }

    private func scale(at time: Double) -> CGFloat {
        switch mood {
        case .idle, .listening: 0.995 + 0.035 * sin(time * .pi / 2)
        case .thinking: 1 + 0.02 * sin(time * 2 * .pi / 0.8)
        case .speaking: 1.04 + 0.04 * sin(time * 2 * .pi / 1.1)
        }
    }
}
