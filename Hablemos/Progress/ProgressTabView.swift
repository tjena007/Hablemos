import HablemosCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ProgressTabView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [LearnerProfile]
    @Query(sort: [SortDescriptor(\MistakeStat.count, order: .reverse), SortDescriptor(\MistakeStat.category)])
    private var mistakes: [MistakeStat]
    @Query private var vocab: [VocabItem]
    @Query private var sessions: [PracticeSession]

    @State private var exportDocument: ProgressBackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImport: Data?
    @State private var errorMessage: String?

    private var currentLevel: CEFRLevel { profiles.first?.level ?? .a1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Progress")
                    .font(.display(28, relativeTo: .largeTitle))
                    .foregroundStyle(Noche.text)
                    .accessibilityAddTraits(.isHeader)
                levelLadder
                totals
                recurringMistakes
                backup
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Noche.bg.ignoresSafeArea())
        .fileExporter(
            isPresented: $isExporting, document: exportDocument, contentType: .json,
            defaultFilename: "hablemos-progress"
        ) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            readImport(result)
        }
        .confirmationDialog(
            "Import progress", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible
        ) {
            Button("Replace current progress", role: .destructive) { runImport(replacing: true) }
            Button("Merge with current progress") { runImport(replacing: false) }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Replace erases your current progress first. Merge keeps it and adds the backup.")
        }
        .alert(
            "Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var levelLadder: some View {
        VStack(alignment: .leading, spacing: 12) {
            UpperLabel(text: "Level")
            HStack(spacing: 8) {
                ForEach(CEFRLevel.allCases, id: \.self) { level in
                    levelStep(level)
                }
            }
        }
        .card()
    }

    private func levelStep(_ level: CEFRLevel) -> some View {
        let all = CEFRLevel.allCases
        let isCurrent = level == currentLevel
        let isDone = all.firstIndex(of: level)! < all.firstIndex(of: currentLevel)!
        return VStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.circle.fill" : isCurrent ? "circle.inset.filled" : "circle")
                .font(.title3)
                .foregroundStyle(isDone || isCurrent ? Noche.brand : Noche.borderDashed)
            Text(level.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCurrent ? Noche.text : Noche.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isCurrent ? Noche.surfaceSel : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(level.rawValue), \(isDone ? "completed" : isCurrent ? "current level" : "locked")")
    }

    private var totals: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(vocab.count)", label: "Words & phrases")
            StatTile(value: Self.formatDuration(sessions.reduce(0) { $0 + $1.durationSeconds }), label: "Speaking time")
            StatTile(value: "\(sessions.count)", label: "Sessions")
        }
    }

    private var recurringMistakes: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(text: "Recurring mistakes")
            if mistakes.isEmpty {
                Text("No mistakes recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(Noche.textMuted)
            } else {
                let maxCount = Double(mistakes.first?.count ?? 1)
                ForEach(mistakes) { stat in
                    mistakeRow(stat, fraction: Double(stat.count) / maxCount)
                }
            }
        }
        .card()
    }

    private func mistakeRow(_ stat: MistakeStat, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(MistakeTally.displayName(for: stat.category))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Noche.missText)
                Spacer()
                Text("\(stat.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Noche.brand)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Noche.missSurface)
                    Capsule().fill(Noche.brandText).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
            if !stat.example.isEmpty {
                Text(stat.example)
                    .font(.caption)
                    .foregroundStyle(Noche.missMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var backup: some View {
        VStack(spacing: 10) {
            SecondaryButton(title: "Export progress (JSON)") { startExport() }
            SecondaryButton(title: "Import progress") { isImporting = true }
        }
    }

    private func startExport() {
        do {
            exportDocument = ProgressBackupDocument(data: try ProgressStore(context: context).exportData())
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func readImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                throw CocoaError(.fileReadNoPermission)
            }
            defer { url.stopAccessingSecurityScopedResource() }
            pendingImport = try Data(contentsOf: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runImport(replacing: Bool) {
        guard let data = pendingImport else { return }
        pendingImport = nil
        do {
            try ProgressStore(context: context).importData(data, replacing: replacing)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func formatDuration(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        return hours > 0 ? "\(hours) h \(rest) min" : "\(rest) min"
    }
}

#Preview {
    let container = try! PersistenceSchema.makeContainer(inMemory: true)
    let context = container.mainContext
    context.insert(LearnerProfile(level: .b1))
    context.insert(MistakeStat(category: "ser_vs_estar", example: "Yo soy cansado", count: 9, lastSeen: .now))
    context.insert(MistakeStat(category: "gender_agreement", example: "la problema", count: 5, lastSeen: .now))
    context.insert(MistakeStat(category: "preterite_vs_imperfect", example: "Ayer comía pizza", count: 2, lastSeen: .now))
    context.insert(VocabItem(phrase: "la cuenta, por favor", firstSeen: .now, timesUsed: 3))
    context.insert(VocabItem(phrase: "con gusto", firstSeen: .now, timesUsed: 1))
    let metrics = SessionMetrics(turns: 8, wordsPerTurn: 9, errorsPerTurn: 1, englishSwitches: 0, averagePauseSeconds: 1)
    context.insert(try! PracticeSession(date: .now, scenarioID: "cafe", level: .b1, durationSeconds: 8040, metrics: metrics))
    return ProgressTabView().modelContainer(container)
}
