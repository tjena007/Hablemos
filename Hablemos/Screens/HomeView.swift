import HablemosCore
import SwiftData
import SwiftUI

struct HomeView: View {
    let model: AppModel
    @Query private var profiles: [LearnerProfile]
    @Query(sort: \MistakeStat.count, order: .reverse) private var mistakes: [MistakeStat]
    @Query(filter: #Predicate<Turn> { $0.roleRaw == "correction" }) private var corrections: [Turn]
    @Environment(\.modelContext) private var modelContext
    @State private var showSettings = false

    private var profile: LearnerProfile? { profiles.first }
    private var level: CEFRLevel { profile?.level ?? .a1 }

    var body: some View {
        VStack(spacing: 0) {
            switch model.tab {
            case .practice: practice
            case .progress: ProgressTabView()
            case .review: ReviewTabView()
            }
            TabBar(selection: Binding(get: { model.tab }, set: { model.tab = $0 }))
        }
    }

    private var practice: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                sessionCard
                levelCard
                weakSpots
                Button("Developer · model spike") { model.go(.spike) }
                    .font(.footnote)
                    .foregroundStyle(Noche.textMuted)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Start session") { model.beginSession(useE2B: profile?.useE2BModel ?? false, context: modelContext) }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Noche.bg)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "es_MX"))).capitalized)
                    .font(.subheadline)
                    .foregroundStyle(Noche.textMuted)
                Text("Hola, \(DemoData.learnerName)")
                    .font(.display(30, relativeTo: .largeTitle))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .foregroundStyle(Noche.saffron)
                Text("\(profile?.dayStreak ?? 0) días")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Noche.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Noche.border))
            .accessibilityElement(children: .combine)
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(Noche.textMuted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var sessionSteps: [(title: String, detail: String)] {
        let scenarioTitle = LevelsConfig.default.defaultScenario(for: level)?.title ?? "Conversation"
        var steps: [(title: String, detail: String)] = []
        let reviewCount = Set(corrections.compactMap { $0.correction?.right.lowercased() }).count
        if reviewCount > 0 { steps.append(("Say it again", "\(min(reviewCount, 5)) phrases from past mistakes · 2 min")) }
        steps.append(("Warm-up: \(scenarioTitle)", "Words first, then sentences · 3 min"))
        steps.append(("Talk with Lucía", "Conversation · 8 min"))
        steps.append(("Run it again", "Same scenario, right after · 3 min"))
        return steps
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's session").font(.display(22))
                Text("about 15 min").font(.subheadline).foregroundStyle(Noche.textMuted)
            }
            ForEach(Array(sessionSteps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(index == 0 ? Noche.onSaffron : Noche.text)
                        .frame(width: 28, height: 28)
                        .background(index == 0 ? Noche.saffron : Noche.surfaceSel, in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title).font(.subheadline.weight(.semibold))
                        Text(step.detail).font(.caption).foregroundStyle(Noche.textMuted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Noche.surfaceHi, border: .clear, borderWidth: 0, radius: 20, padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(level.next.map { "\(level.rawValue) → \($0.rawValue)" } ?? "\(level.rawValue) · top level")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(profile?.strongSessionStreak ?? 0) of 3 strong sessions").font(.caption).foregroundStyle(Noche.textMuted)
            }
            SegmentProgress(total: 3, filled: profile?.strongSessionStreak ?? 0, height: 8, emptyColor: Noche.surfaceHi)
        }
        .card(radius: 16)
    }

    private var weakSpots: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(text: "Weak spots")
            if mistakes.isEmpty {
                Text("Nothing yet. Finish a session and your recurring mistakes show up here.")
                    .font(.footnote)
                    .foregroundStyle(Noche.textMuted)
            }
            ForEach(Array(mistakes.prefix(3).enumerated()), id: \.element.category) { index, stat in
                HStack {
                    Chip(
                        text: MistakeTally.displayName(for: stat.category),
                        foreground: index < 2 ? Noche.coralText : Noche.textSoft,
                        background: index < 2 ? Noche.coralSurface : Noche.surfaceHi
                    )
                    Spacer()
                    Text("seen \(stat.count)×").font(.caption).foregroundStyle(Noche.textMuted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct TabBar: View {
    @Binding var selection: HomeTab

    var body: some View {
        HStack {
            item("Practice", systemImage: "bubble.left", tab: .practice)
            item("Progress", systemImage: "chart.bar", tab: .progress)
            item("Review", systemImage: "book", tab: .review)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Noche.navBg)
        .overlay(alignment: .top) { Rectangle().fill(Noche.border).frame(height: 1) }
    }

    private func item(_ title: String, systemImage: String, tab: HomeTab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 20, weight: .medium))
                Text(title).font(.caption.weight(selection == tab ? .semibold : .regular))
            }
            .foregroundStyle(selection == tab ? Noche.mint : Noche.textMuted)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}
