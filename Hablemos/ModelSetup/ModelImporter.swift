import Foundation
import Observation

@MainActor
@Observable
final class ModelImporter {
    enum State: Equatable {
        case idle
        case importing(Double)
        case failed(String)
        case done
    }

    private(set) var state: State = .idle
    @ObservationIgnored private var task: Task<Void, Never>?

    /// `source` is the security-scoped URL handed back by `.fileImporter`.
    func start(from source: URL, variant: ModelVariant) {
        guard task == nil else { return }
        state = .importing(0)
        task = Task {
            defer { task = nil }
            do {
                try await Self.copy(from: source, variant: variant) { fraction in
                    Task { @MainActor in
                        if case .importing = self.state { self.state = .importing(fraction) }
                    }
                }
                state = .done
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        task?.cancel()
    }

    private nonisolated static func copy(
        from source: URL, variant: ModelVariant, progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            guard source.startAccessingSecurityScopedResource() else { throw ModelSetupError.cannotAccessFile }
            defer { source.stopAccessingSecurityScopedResource() }

            let destination = try ModelStore.url(for: variant)
            let partial = destination.appendingPathExtension("partial")
            let fm = FileManager.default
            if fm.fileExists(atPath: partial.path) { try fm.removeItem(at: partial) }
            fm.createFile(atPath: partial.path, contents: nil)

            do {
                let total = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? variant.expectedBytes
                let reader = try FileHandle(forReadingFrom: source)
                let writer = try FileHandle(forWritingTo: partial)
                defer {
                    try? reader.close()
                    try? writer.close()
                }
                var copied: Int64 = 0
                var lastReported = 0.0
                while let chunk = try reader.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
                    try Task.checkCancellation()
                    try writer.write(contentsOf: chunk)
                    copied += Int64(chunk.count)
                    let fraction = total > 0 ? min(1, Double(copied) / Double(total)) : 0
                    if fraction - lastReported >= 0.005 {
                        lastReported = fraction
                        progress(fraction)
                    }
                }
                try writer.synchronize()
                try ModelFileValidation.validateImport(size: copied, expected: variant.expectedBytes)
            } catch {
                try? fm.removeItem(at: partial)
                throw error
            }
            try ModelFileValidation.moveIntoPlace(partial, to: destination)
        }.value
    }
}
