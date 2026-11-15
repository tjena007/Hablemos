import Foundation

enum ModelSetupError: LocalizedError, Equatable {
    case sizeMismatch(actual: Int64, expected: Int64)
    case truncatedDownload(received: Int64, serverLength: Int64)
    case cannotAccessFile

    var errorDescription: String? {
        switch self {
        case let .sizeMismatch(actual, expected):
            "The file is \(Self.format(actual)) but the model should be about \(Self.format(expected)). It is incomplete or the wrong file."
        case let .truncatedDownload(received, serverLength):
            "The download ended early: received \(Self.format(received)) of \(Self.format(serverLength))."
        case .cannotAccessFile:
            "Couldn't access the selected file."
        }
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

enum ModelFileValidation {
    // Matches the threshold ModelStore.isInstalled uses.
    static func minimumBytes(expected: Int64) -> Int64 { expected * 98 / 100 }

    static func isAcceptableSize(_ size: Int64, expected: Int64) -> Bool {
        size >= minimumBytes(expected: expected)
    }

    /// `serverLength` is the length the server reported (nil/<=0 when unknown).
    static func validateDownload(size: Int64, serverLength: Int64?, expected: Int64) throws {
        if let serverLength, serverLength > 0, size != serverLength {
            throw ModelSetupError.truncatedDownload(received: size, serverLength: serverLength)
        }
        guard isAcceptableSize(size, expected: expected) else {
            throw ModelSetupError.sizeMismatch(actual: size, expected: expected)
        }
    }

    static func validateImport(size: Int64, expected: Int64) throws {
        guard isAcceptableSize(size, expected: expected) else {
            throw ModelSetupError.sizeMismatch(actual: size, expected: expected)
        }
    }

    static func moveIntoPlace(_ partial: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(destination, withItemAt: partial)
        } else {
            try fm.moveItem(at: partial, to: destination)
        }
        var final = destination
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try final.setResourceValues(values)
    }
}
