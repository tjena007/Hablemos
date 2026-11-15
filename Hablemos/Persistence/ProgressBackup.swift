import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ProgressBackup: Codable, Equatable {
    static let currentVersion = 1

    struct Profile: Codable, Equatable {
        var levelRaw: String
        var strongSessionStreak: Int
        var dayStreak: Int
        var lastPracticeDate: Date?
        var localeIdentifier: String
        var voiceIdentifier: String?
        var ttsRateOverride: Float?
        var useE2BModel: Bool
    }

    struct Session: Codable, Equatable {
        var id: UUID
        var date: Date
        var scenarioID: String
        var levelRaw: String
        var durationSeconds: Double
        var metrics: SessionMetricsDTO
        var summaryJSON: String?
        var turns: [Turn]
    }

    struct Turn: Codable, Equatable {
        var roleRaw: String
        var text: String
        var correctionWrong: String?
        var correctionRight: String?
        var correctionExplanation: String?
        var timestamp: Date
    }

    struct SessionMetricsDTO: Codable, Equatable {
        var turns: Int
        var wordsPerTurn: Double
        var errorsPerTurn: Double
        var englishSwitches: Int
        var averagePauseSeconds: Double
    }

    struct Mistake: Codable, Equatable {
        var category: String
        var example: String
        var count: Int
        var lastSeen: Date
    }

    struct Vocab: Codable, Equatable {
        var phrase: String
        var firstSeen: Date
        var timesUsed: Int
    }

    var version: Int
    var profile: Profile
    var sessions: [Session]
    var mistakes: [Mistake]
    var vocab: [Vocab]
}

enum ProgressBackupError: LocalizedError, Equatable {
    case unreadable(String)
    case unsupportedVersion(found: Int, supported: Int)
    case malformed(String)
    case invalidLevel(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let detail):
            "The file is not a valid Hablemos backup: \(detail)"
        case .unsupportedVersion(let found, let supported):
            "Backup version \(found) is not supported (this app reads version \(supported))."
        case .malformed(let detail):
            "The backup is missing or has invalid data: \(detail)"
        case .invalidLevel(let raw):
            "The backup contains an unknown level \"\(raw)\"."
        }
    }
}

struct ProgressBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
