import HablemosCore
import SwiftData
import SwiftUI

struct ReviewTabView: View {
    @Query(filter: #Predicate<Turn> { $0.roleRaw == "correction" }, sort: \Turn.timestamp, order: .reverse)
    private var corrections: [Turn]
    @Query(sort: \VocabItem.firstSeen, order: .reverse) private var vocab: [VocabItem]
    @Environment(SpeechPlayer.self) private var player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review")
                    .font(.display(30, relativeTo: .largeTitle))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                mistakesSection
                vocabSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var mistakesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(text: "Mistakes to remember")
            if corrections.isEmpty {
                emptyNote("Corrections from your conversations show up here.")
            }
            ForEach(corrections.prefix(30)) { turn in
                if let correction = turn.correction {
                    HStack(alignment: .top, spacing: 12) {
                        PlayCircle(size: 36) { player.say(correction.right) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Text(correction.wrong).strikethrough()) → \(Text(correction.right).fontWeight(.bold))")
                                .font(.subheadline)
                            if !correction.explanation.isEmpty {
                                Text(correction.explanation).font(.footnote).foregroundStyle(Noche.textMuted)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 14, padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                }
            }
        }
    }

    private var vocabSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(text: "Words and phrases you picked up")
            if vocab.isEmpty {
                emptyNote("New words from your sessions show up here.")
            }
            ForEach(vocab.prefix(60)) { item in
                HStack(spacing: 12) {
                    PlayCircle(size: 36) { player.say(item.phrase) }
                    Text(item.phrase).font(.callout.weight(.medium))
                    Spacer()
                    Text("used \(item.timesUsed)×").font(.caption).foregroundStyle(Noche.textMuted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(Noche.textMuted)
    }
}
