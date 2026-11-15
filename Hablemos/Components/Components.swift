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
                .foregroundStyle(Noche.onSaffron)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(Noche.saffron, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
    }
}

struct PlayCircle: View {
    var size: CGFloat = 36
    var fill: Color = Noche.surfaceMint
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.4))
                .foregroundStyle(Noche.mint)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play")
    }
}

private struct MicCircle: View {
    let systemImage: String
    var isActive = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(Noche.onSaffron)
            .frame(width: 76, height: 76)
            .background(Noche.saffron, in: Circle())
            .overlay(Circle().strokeBorder(Noche.micRing, lineWidth: 6).padding(-6))
            .scaleEffect(isActive ? 1.08 : 1)
            .animation(.spring(duration: 0.2), value: isActive)
            .padding(6)
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
                    .fill(index < filled ? Noche.saffron : emptyColor)
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
                Rectangle().fill(Noche.saffron).frame(width: proxy.size.width * fraction)
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
                .buttonStyle(.plain)
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
