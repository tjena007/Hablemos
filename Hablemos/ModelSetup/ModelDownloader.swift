import Foundation
import Observation

@MainActor
@Observable
final class ModelDownloader {
    enum State: Equatable {
        case idle
        case downloading(Double)
        case paused
        case failed(String)
        case done
    }

    let variant: ModelVariant
    private(set) var state: State = .idle
    private(set) var bytesWritten: Int64 = 0
    private(set) var totalBytes: Int64

    var fraction: Double {
        totalBytes > 0 ? min(1, Double(bytesWritten) / Double(totalBytes)) : 0
    }

    @ObservationIgnored private var session: URLSession?
    @ObservationIgnored private var task: URLSessionDownloadTask?
    @ObservationIgnored private var retiredTaskIDs: Set<Int> = []

    init(variant: ModelVariant) {
        self.variant = variant
        totalBytes = variant.expectedBytes
    }

    /// Call on launch: re-attaches to a background task, or detects saved resume data.
    func restore() async {
        guard state == .idle || state == .paused else { return }
        if ModelStore.isInstalled(variant) {
            state = .done
            return
        }
        let existing = await makeSession().allTasks.compactMap { $0 as? URLSessionDownloadTask }
        if let running = existing.first {
            task = running
            bytesWritten = running.countOfBytesReceived
            if running.countOfBytesExpectedToReceive > 0 { totalBytes = running.countOfBytesExpectedToReceive }
            state = .downloading(fraction)
            running.resume()
            return
        }
        if let resume = try? resumeURL(), FileManager.default.fileExists(atPath: resume.path) {
            state = .paused
        }
    }

    func start() {
        guard task == nil else { return }
        do {
            let session = makeSession()
            let resume = try resumeURL()
            let newTask: URLSessionDownloadTask
            if FileManager.default.fileExists(atPath: resume.path) {
                newTask = session.downloadTask(withResumeData: try Data(contentsOf: resume))
            } else {
                newTask = session.downloadTask(with: variant.downloadURL)
            }
            task = newTask
            state = .downloading(fraction)
            newTask.resume()
        } catch {
            fail(error)
        }
    }

    func pause() {
        guard let running = task else { return }
        retire(running)
        state = .paused
        running.cancel { [variant] data in
            Task { @MainActor in
                do {
                    try Self.saveResumeData(data, for: variant)
                } catch {
                    self.fail(error)
                }
            }
        }
    }

    func cancel() {
        if let running = task {
            retire(running)
            running.cancel()
        }
        removeTransientFiles()
        bytesWritten = 0
        state = .idle
    }

    private func retire(_ running: URLSessionDownloadTask) {
        retiredTaskIDs.insert(running.taskIdentifier)
        task = nil
    }

    private func makeSession() -> URLSession {
        if let session { return session }
        let config = URLSessionConfiguration.background(
            withIdentifier: "\(Bundle.main.bundleIdentifier ?? "Hablemos").model-download.\(variant.rawValue)"
        )
        config.sessionSendsLaunchEvents = true
        let delegate = DownloadDelegate(variant: variant) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        let created = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        session = created
        return created
    }

    private func handle(_ event: DownloadDelegate.Event) {
        guard !retiredTaskIDs.contains(event.taskID) else { return }
        switch event.kind {
        case let .progress(written, total):
            bytesWritten = written
            if total > 0 { totalBytes = total }
            state = .downloading(fraction)
        case let .downloaded(partial, serverLength):
            finalize(partial: partial, serverLength: serverLength)
        case let .failed(error, resumeData):
            task = nil
            do {
                try Self.saveResumeData(resumeData, for: variant)
            } catch {
                fail(error)
                return
            }
            state = .failed(error.localizedDescription)
        }
    }

    private func finalize(partial: URL, serverLength: Int64?) {
        task = nil
        do {
            let size = try partial.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? 0
            try ModelFileValidation.validateDownload(size: size, serverLength: serverLength, expected: variant.expectedBytes)
            try ModelFileValidation.moveIntoPlace(partial, to: ModelStore.url(for: variant))
            try? FileManager.default.removeItem(at: resumeURL())
            bytesWritten = size
            state = .done
        } catch {
            try? FileManager.default.removeItem(at: partial)
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        state = .failed(error.localizedDescription)
    }

    private func resumeURL() throws -> URL {
        try ModelStore.directory().appending(path: variant.fileName + ".resume")
    }

    private func removeTransientFiles() {
        guard let dir = try? ModelStore.directory() else { return }
        for suffix in [".resume", ".partial"] {
            try? FileManager.default.removeItem(at: dir.appending(path: variant.fileName + suffix))
        }
    }

    private static func saveResumeData(_ data: Data?, for variant: ModelVariant) throws {
        let url = try ModelStore.directory().appending(path: variant.fileName + ".resume")
        if let data {
            try data.write(to: url, options: .atomic)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    struct Event: Sendable {
        enum Kind: Sendable {
            case progress(written: Int64, total: Int64)
            case downloaded(partial: URL, serverLength: Int64?)
            case failed(Error, resumeData: Data?)
        }

        let taskID: Int
        let kind: Kind
    }

    private let variant: ModelVariant
    private let onEvent: @Sendable (Event) -> Void

    init(variant: ModelVariant, onEvent: @escaping @Sendable (Event) -> Void) {
        self.variant = variant
        self.onEvent = onEvent
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        onEvent(Event(taskID: downloadTask.taskIdentifier, kind: .progress(written: totalBytesWritten, total: totalBytesExpectedToWrite)))
    }

    // The system deletes `location` when this returns, so the move must happen here.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let id = downloadTask.taskIdentifier
        do {
            if let http = downloadTask.response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Server responded with HTTP \(http.statusCode)."])
            }
            let partial = try ModelStore.directory().appending(path: variant.fileName + ".partial")
            if FileManager.default.fileExists(atPath: partial.path) {
                try FileManager.default.removeItem(at: partial)
            }
            try FileManager.default.moveItem(at: location, to: partial)
            let length = downloadTask.countOfBytesExpectedToReceive
            onEvent(Event(taskID: id, kind: .downloaded(partial: partial, serverLength: length > 0 ? length : nil)))
        } catch {
            onEvent(Event(taskID: id, kind: .failed(error, resumeData: nil)))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        onEvent(Event(taskID: task.taskIdentifier, kind: .failed(error, resumeData: resumeData)))
    }
}
