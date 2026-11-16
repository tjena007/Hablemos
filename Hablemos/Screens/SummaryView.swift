import SwiftUI

struct SummaryView: View {
    let result: SessionResult
    let onRoundTwo: () -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    Orb(size: 64, mood: .speaking)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(result.scenarioTitle) · \(max(1, Int(result.durationSeconds / 60))) min").font(.subheadline).foregroundStyle(Noche.textMuted)
                        Text("¡Bien hecho!")
                            .font(.display(30, relativeTo: .largeTitle))
                            .tracking(-0.5)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                .entrance(0)
                HStack(spacing: 10) {
                    StatTile(value: String(format: "%.1f", result.metrics.wordsPerTurn), label: "words / turn")
                    StatTile(value: String(format: "%.1f", result.metrics.errorsPerTurn), label: "errors / turn")
                    StatTile(value: "\(result.metrics.turns)", label: "turns")
                    StatTile(value: "\(result.metrics.englishSwitches)", label: "English switches")
                }
                .entrance(1)
                promotionBanner.entrance(2)
                ForEach([result.summaryError, result.exportError].compactMap(\.self), id: \.self) { error in
                    Text(error).font(.footnote).foregroundStyle(Noche.missText)
                }
                if !result.mistakes.isEmpty {
                    SectionHeading(text: "Say these lines correctly")
                    ForEach(Array(result.mistakes.enumerated()), id: \.offset) { index, mistake in
                        fixRow(wrong: mistake.original, right: mistake.corrected, note: mistake.explanation, isDone: index > 0)
                    }
                    Text("These lines go into review: first due tomorrow")
                        .font(.footnote)
                        .foregroundStyle(Noche.textMuted)
                }
                if !result.newWords.isEmpty {
                    SectionHeading(text: "New words")
                    FlowLayout(spacing: 8) {
                        ForEach(result.newWords, id: \.self) { Chip(text: $0) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step 4 · Run it again now").font(.callout.weight(.semibold))
                    Text("Same café, same goal. Lucía changes the small talk.")
                        .font(.footnote)
                        .foregroundStyle(Noche.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(fill: Noche.surfaceHi, border: .clear, borderWidth: 0, radius: 16)
                PrimaryButton(title: "Start round 2", height: 54, action: onRoundTwo)
                SecondaryButton(title: "Done for today", action: onDone)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Noche.bg)
        }
    }

    private var promotionBanner: some View {
        let text: String
        if let unlocked = result.unlockedLevel {
            text = "Level up! \(unlocked.rawValue) unlocked."
        } else if result.isStrong {
            text = "Strong session: \(result.streak) of \(result.streakRequired) toward the next level."
        } else {
            text = "Not a strong session this time. Aim for under 2 errors a turn and 8+ words a turn."
        }
        return Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(result.isStrong ? Noche.mint : Noche.textSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(fill: result.isStrong ? Noche.surfaceMint : Noche.surface, border: .clear, borderWidth: 0, radius: 14)
    }

    private func fixRow(wrong: String, right: String, note: String, isDone: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                CorrectionLine(wrong: wrong, right: right)
                Text(note).font(.footnote).foregroundStyle(Noche.textMuted)
            }
            Spacer()
            Image(systemName: isDone ? "checkmark" : "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDone ? Noche.mint : Noche.onBrand)
                .frame(width: 40, height: 40)
                .background(isDone ? Noche.surfaceMint : Noche.brand, in: Circle())
                .accessibilityLabel(isDone ? "Practiced" : "Practice now")
        }
        .card(
            border: isDone ? Noche.border : Noche.brand,
            borderWidth: isDone ? 1 : 2,
            radius: 14
        )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
