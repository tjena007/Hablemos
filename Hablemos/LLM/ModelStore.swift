import Foundation

enum ModelVariant: String, CaseIterable, Identifiable {
    case e4b, e2b

    var id: String { rawValue }

    var fileName: String {
        switch self {
        case .e4b: "gemma-4-E4B-it.litertlm"
        case .e2b: "gemma-4-E2B-it.litertlm"
        }
    }

    var expectedBytes: Int64 {
        switch self {
        case .e4b: 3_659_530_240
        case .e2b: 2_580_000_000
        }
    }

    var downloadURL: URL {
        let repo = self == .e4b ? "gemma-4-E4B-it-litert-lm" : "gemma-4-E2B-it-litert-lm"
        return URL(string: "https://huggingface.co/litert-community/\(repo)/resolve/main/\(fileName)")!
    }
}

enum ModelStore {
    static func directory() throws -> URL {
        var url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Models", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        return url
    }

    static func url(for variant: ModelVariant) throws -> URL {
        try directory().appending(path: variant.fileName)
    }

    static func installedSize(of variant: ModelVariant) -> Int64? {
        guard let url = try? url(for: variant),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        else { return nil }
        return Int64(size)
    }

    static func isInstalled(_ variant: ModelVariant) -> Bool {
        installedSize(of: variant).map { $0 >= variant.expectedBytes * 98 / 100 } ?? false
    }
}
