import HablemosCore
import SwiftData
import SwiftUI

struct HomeView: View {
    let model: AppModel
    @Query private var profiles: [LearnerProfile]
    @Query(sort: \MistakeStat.count, order: .reverse) private var mistakes: [MistakeStat]
    @Query(filter: #Predicate<Turn> { $0.roleRaw == "correction" }) private var corrections: [Turn]
    @Query private var sessions: [PracticeSession]
    @Environment(\.modelContext) private var modelContext
    @State private var showSettings = false

    private static let dailyGoalMinutes = 10.0

    private var profile: LearnerProfile? { profiles.first }
    private var level: CEFRLevel { profile?.level ?? .a1 }
    private var scenario: ScenarioConfig? { LevelsConfig.default.defaultScenario(for: level) }
    private var reviewCount: Int { Set(corrections.compactMap { $0.correction?.right.lowercased() }).count }
    private var minutesToday: Double {
        sessions.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.durationSeconds } / 60
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch model.tab {
                case .today: today
                case .path: PathPlaceholderView()
                case .phrases: ReviewTabView()
                case .me: ProgressTabView()
                }
            }
            .id(model.tab)
            .transition(.opacity)
            .frame(maxHeight: .infinity)
            TabBar(selection: Binding(get: { model.tab }, set: { model.tab = $0 }), onTalk: beginSession)
        }
        .animation(.easeInOut(duration: 0.2), value: model.tab)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private func beginSession() {
        model.beginSession(useE2B: profile?.useE2BModel ?? false, useApple: profile?.useAppleModel ?? false, context: modelContext)
    }

    private var today: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header.entrance(0)
                goalCard.entrance(1)
                continueCard.entrance(2)
                HStack(spacing: 12) {
                    tile(icon: "arrow.counterclockwise", title: "Review", detail: reviewCount == 0 ? "Nothing due yet" : "\(reviewCount) phrases to fix") { model.tab = .phrases }
                    tile(icon: "chart.bar.fill", title: level.next.map { "\(level.rawValue) → \($0.rawValue)" } ?? level.rawValue, detail: "\(profile?.strongSessionStreak ?? 0) of 3 strong sessions") { model.tab = .me }
                }
                .entrance(3)
                weakSpots.entrance(4)
                Button("Developer · model spike") { model.go(.spike) }
                    .font(.footnote)
                    .foregroundStyle(Noche.textMuted)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Buenos días"
        case 12..<19: "Buenas tardes"
        default: "Buenas noches"
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(DemoData.learnerName)")
                    .font(.display(30, relativeTo: .largeTitle))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text(scenario.map { "\($0.title) is up next" } ?? "Ready when you are")
                    .font(.subheadline)
                    .foregroundStyle(Noche.textMuted)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Noche.brandText)
                    .symbolEffect(.bounce, value: profile?.dayStreak)
                Text("\(profile?.dayStreak ?? 0)")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Noche.surfaceHi, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(profile?.dayStreak ?? 0) day streak")
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(Noche.textMuted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
    }

    private var goalCard: some View {
        let fraction = min(minutesToday / Self.dailyGoalMinutes, 1)
        let remaining = max(Self.dailyGoalMinutes - minutesToday, 0)
        return HStack(spacing: 16) {
            GoalRing(fraction: fraction)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(minutesToday.rounded(.down))) of \(Int(Self.dailyGoalMinutes)) min practised")
                    .font(.callout.weight(.semibold))
                Text(remaining == 0 ? "Goal met today. ¡Muy bien!" : "\(Int(remaining.rounded(.up))) more minutes for today's goal")
                    .font(.subheadline)
                    .foregroundStyle(Noche.textMuted)
            }
            Spacer(minLength: 0)
        }
        .card(fill: Noche.surface, border: .clear, borderWidth: 0, radius: 20, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        .accessibilityElement(children: .combine)
    }

    private var continueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                UpperLabel(text: model.isWarmupDoneToday ? "Pick up where you left off" : "Continue", color: Noche.brandText)
                Spacer()
                Text("≈ 15 min").font(.footnote).foregroundStyle(Noche.textMuted)
            }
            HStack(spacing: 16) {
                Orb(size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text(scenario?.title ?? "Talk with Lucía")
                        .font(.display(22))
                    Text(model.isWarmupDoneToday ? "Warm-up done. Now talk it through with Lucía." : "Warm up on the key words, then talk it through with Lucía.")
                        .font(.subheadline)
                        .foregroundStyle(Noche.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            PrimaryButton(title: model.isWarmupDoneToday ? "Resume with Lucía" : "Start with Lucía", height: 52, action: beginSession)
        }
        .card(fill: Noche.surfaceHi, border: .clear, borderWidth: 0, radius: 24, padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
    }

    private func tile(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Noche.mint)
                Text(title).font(.callout.weight(.semibold)).foregroundStyle(Noche.text)
                Text(detail).font(.footnote).foregroundStyle(Noche.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .card(fill: Noche.surface, border: .clear, borderWidth: 0, radius: 20, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        }
        .buttonStyle(PressableStyle())
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
                        foreground: index < 2 ? Noche.missText : Noche.textSoft,
                        background: index < 2 ? Noche.missSurface : Noche.surfaceHi
                    )
                    Spacer()
                    Text("seen \(stat.count)×").font(.caption).foregroundStyle(Noche.textMuted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Fills to today's progress when it appears.
private struct GoalRing: View {
    let fraction: Double
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            Circle().stroke(Noche.surfaceSel, lineWidth: 7)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(Noche.brandText, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(4)
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.2)) { shown = fraction } }
        .onChange(of: fraction) { withAnimation(.hablemos) { shown = fraction } }
        .accessibilityHidden(true)
    }
}

private struct PathPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UpperLabel(text: "Coming soon", color: Noche.brandText).entrance(0)
            Text("Your path")
                .font(.display(30, relativeTo: .largeTitle))
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
                .entrance(1)
            Text("Units and lessons, what you're learning today and what's next, will live here.")
                .font(.subheadline)
                .foregroundStyle(Noche.textSoft)
                .entrance(2)
            Spacer()
            Orb(size: 120).frame(maxWidth: .infinity).entrance(3)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}

private struct TabBar: View {
    @Binding var selection: HomeTab
    let onTalk: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            item("Today", systemImage: "house", tab: .today)
            item("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath", tab: .path)
            Button(action: onTalk) {
                Orb(size: 44)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Talk with Lucía")
            item("Phrases", systemImage: "book", tab: .phrases)
            item("Me", systemImage: "person", tab: .me)
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
                Image(systemName: selection == tab ? systemImage + ".fill" : systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .symbolEffect(.bounce, value: selection == tab)
                    .frame(height: 24)
                Text(title).font(.caption2.weight(selection == tab ? .semibold : .regular))
            }
            .foregroundStyle(selection == tab ? Noche.brandText : Noche.textMuted)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}

#Preview {
    HomeView(model: AppModel())
        .background(Noche.bg)
        .foregroundStyle(Noche.text)
        .preferredColorScheme(.dark)
        .environment(SpeechPlayer(tts: MockTextToSpeech()))
        .modelContainer(try! PersistenceSchema.makeContainer(inMemory: true))
}
