import Foundation
import HablemosCore
import SwiftData

struct TurnRecord {
    var roleRaw: String
    var text: String
    var correction: Correction?
    var timestamp: Date
}

struct MistakeRecord {
    var category: String
    var example: String
}

@MainActor
struct ProgressStore {
    let context: ModelContext
    var rule = PromotionRule()
    var calendar = Calendar.current

    init(context: ModelContext, rule: PromotionRule = PromotionRule(), calendar: Calendar = .current) {
        self.context = context
        self.rule = rule
        self.calendar = calendar
    }

    func profile() throws -> LearnerProfile {
        if let existing = try context.fetch(FetchDescriptor<LearnerProfile>()).first {
            return existing
        }
        let created = LearnerProfile()
        context.insert(created)
        try context.save()
        return created
    }

    @discardableResult
    func record(
        date: Date,
        scenarioID: String,
        level: CEFRLevel,
        durationSeconds: Double,
        metrics: SessionMetrics,
        summaryJSON: String? = nil,
        turns: [TurnRecord],
        mistakes: [MistakeRecord] = [],
        vocab: [String] = []
    ) throws -> PracticeSession {
        let session = try PracticeSession(
            date: date, scenarioID: scenarioID, level: level,
            durationSeconds: durationSeconds, metrics: metrics, summaryJSON: summaryJSON
        )
        context.insert(session)
        for record in turns {
            let turn = Turn(
                roleRaw: record.roleRaw, text: record.text,
                correction: record.correction, timestamp: record.timestamp
            )
            context.insert(turn)
            turn.session = session
        }

        try tally(mistakes, at: date)
        try tally(vocab, at: date)
        try updateProfile(metrics: metrics, practicedOn: date)
        try context.save()
        return session
    }

    /// Rewritten after every session so the latest progress can be copied off a connected iPhone.
    static var autoExportURL: URL { URL.documentsDirectory.appending(path: "hablemos-progress.json") }

    private func tally(_ mistakes: [MistakeRecord], at date: Date) throws {
        for mistake in mistakes {
            let category = mistake.category
            let predicate = #Predicate<MistakeStat> { $0.category == category }
            if let stat = try context.fetch(FetchDescriptor(predicate: predicate)).first {
                stat.count += 1
                stat.example = mistake.example
                stat.lastSeen = max(stat.lastSeen, date)
            } else {
                context.insert(MistakeStat(category: category, example: mistake.example, count: 1, lastSeen: date))
            }
        }
    }

    private func tally(_ phrases: [String], at date: Date) throws {
        for phrase in phrases {
            let predicate = #Predicate<VocabItem> { $0.phrase == phrase }
            if let item = try context.fetch(FetchDescriptor(predicate: predicate)).first {
                item.timesUsed += 1
            } else {
                context.insert(VocabItem(phrase: phrase, firstSeen: date, timesUsed: 1))
            }
        }
    }

    private func updateProfile(metrics: SessionMetrics, practicedOn date: Date) throws {
        let profile = try profile()
        let outcome = rule.apply(streak: profile.strongSessionStreak, session: metrics)
        profile.strongSessionStreak = outcome.streak
        if outcome.unlocksNextLevel, let next = profile.level.next {
            profile.level = next
        }

        guard let last = profile.lastPracticeDate else {
            profile.dayStreak = 1
            profile.lastPracticeDate = date
            return
        }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: date)
        ).day ?? 0
        switch days {
        case 0: break
        case 1: profile.dayStreak += 1
        case ..<0: return
        default: profile.dayStreak = 1
        }
        profile.lastPracticeDate = max(last, date)
    }

    // MARK: Backup

    func exportData() throws -> Data {
        let profile = try profile()
        let sessions = try context.fetch(FetchDescriptor<PracticeSession>(sortBy: [SortDescriptor(\.date)]))
        let backup = try ProgressBackup(
            version: ProgressBackup.currentVersion,
            profile: .init(
                levelRaw: profile.levelRaw, strongSessionStreak: profile.strongSessionStreak,
                dayStreak: profile.dayStreak, lastPracticeDate: profile.lastPracticeDate,
                localeIdentifier: profile.localeIdentifier, voiceIdentifier: profile.voiceIdentifier,
                ttsRateOverride: profile.ttsRateOverride, useE2BModel: profile.useE2BModel
            ),
            sessions: sessions.map { session in
                let metrics = try session.metrics
                return ProgressBackup.Session(
                    id: session.id, date: session.date, scenarioID: session.scenarioID,
                    levelRaw: session.levelRaw, durationSeconds: session.durationSeconds,
                    metrics: .init(
                        turns: metrics.turns, wordsPerTurn: metrics.wordsPerTurn,
                        errorsPerTurn: metrics.errorsPerTurn, englishSwitches: metrics.englishSwitches,
                        averagePauseSeconds: metrics.averagePauseSeconds
                    ),
                    summaryJSON: session.summaryJSON,
                    turns: (session.turns ?? []).sorted { $0.timestamp < $1.timestamp }.map {
                        .init(
                            roleRaw: $0.roleRaw, text: $0.text, correctionWrong: $0.correctionWrong,
                            correctionRight: $0.correctionRight, correctionExplanation: $0.correctionExplanation,
                            timestamp: $0.timestamp
                        )
                    }
                )
            },
            mistakes: context.fetch(FetchDescriptor<MistakeStat>(sortBy: [SortDescriptor(\.category)])).map {
                .init(category: $0.category, example: $0.example, count: $0.count, lastSeen: $0.lastSeen)
            },
            vocab: context.fetch(FetchDescriptor<VocabItem>(sortBy: [SortDescriptor(\.phrase)])).map {
                .init(phrase: $0.phrase, firstSeen: $0.firstSeen, timesUsed: $0.timesUsed)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    /// `replacing: true` wipes existing progress first; otherwise merges (sessions deduped by id, counts summed, existing profile kept).
    func importData(_ data: Data, replacing: Bool) throws {
        let backup = try Self.decodeBackup(data)

        if replacing {
            try context.delete(model: PracticeSession.self)
            try context.delete(model: MistakeStat.self)
            try context.delete(model: VocabItem.self)
            try context.save()

            let profile = try profile()
            let source = backup.profile
            profile.levelRaw = source.levelRaw
            profile.strongSessionStreak = source.strongSessionStreak
            profile.dayStreak = source.dayStreak
            profile.lastPracticeDate = source.lastPracticeDate
            profile.localeIdentifier = source.localeIdentifier
            profile.voiceIdentifier = source.voiceIdentifier
            profile.ttsRateOverride = source.ttsRateOverride
            profile.useE2BModel = source.useE2BModel
        }

        let existingIDs = Set(try context.fetch(FetchDescriptor<PracticeSession>()).map(\.id))
        for source in backup.sessions where !existingIDs.contains(source.id) {
            let session = try PracticeSession(
                id: source.id, date: source.date, scenarioID: source.scenarioID,
                level: CEFRLevel(rawValue: source.levelRaw)!, durationSeconds: source.durationSeconds,
                metrics: SessionMetrics(
                    turns: source.metrics.turns, wordsPerTurn: source.metrics.wordsPerTurn,
                    errorsPerTurn: source.metrics.errorsPerTurn, englishSwitches: source.metrics.englishSwitches,
                    averagePauseSeconds: source.metrics.averagePauseSeconds
                ),
                summaryJSON: source.summaryJSON
            )
            context.insert(session)
            for turnSource in source.turns {
                let turn = Turn(roleRaw: turnSource.roleRaw, text: turnSource.text, timestamp: turnSource.timestamp)
                turn.correctionWrong = turnSource.correctionWrong
                turn.correctionRight = turnSource.correctionRight
                turn.correctionExplanation = turnSource.correctionExplanation
                context.insert(turn)
                turn.session = session
            }
        }

        for source in backup.mistakes {
            let category = source.category
            let predicate = #Predicate<MistakeStat> { $0.category == category }
            if let stat = try context.fetch(FetchDescriptor(predicate: predicate)).first {
                stat.count += source.count
                if source.lastSeen > stat.lastSeen {
                    stat.lastSeen = source.lastSeen
                    stat.example = source.example
                }
            } else {
                context.insert(MistakeStat(
                    category: category, example: source.example, count: source.count, lastSeen: source.lastSeen
                ))
            }
        }

        for source in backup.vocab {
            let phrase = source.phrase
            let predicate = #Predicate<VocabItem> { $0.phrase == phrase }
            if let item = try context.fetch(FetchDescriptor(predicate: predicate)).first {
                item.timesUsed += source.timesUsed
                item.firstSeen = min(item.firstSeen, source.firstSeen)
            } else {
                context.insert(VocabItem(phrase: phrase, firstSeen: source.firstSeen, timesUsed: source.timesUsed))
            }
        }
        try context.save()
    }

    private static func decodeBackup(_ data: Data) throws -> ProgressBackup {
        struct Header: Decodable { let version: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw ProgressBackupError.unreadable(String(describing: error))
        }
        guard header.version == ProgressBackup.currentVersion else {
            throw ProgressBackupError.unsupportedVersion(found: header.version, supported: ProgressBackup.currentVersion)
        }

        let backup: ProgressBackup
        do {
            backup = try decoder.decode(ProgressBackup.self, from: data)
        } catch {
            throw ProgressBackupError.malformed(String(describing: error))
        }

        let levels = ([backup.profile.levelRaw] + backup.sessions.map(\.levelRaw))
        if let bad = levels.first(where: { CEFRLevel(rawValue: $0) == nil }) {
            throw ProgressBackupError.invalidLevel(bad)
        }
        return backup
    }
}
