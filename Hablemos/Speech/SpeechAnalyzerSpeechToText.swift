import AVFoundation
import HablemosCore
import OSLog
import Speech

enum SpeechToTextError: Error {
    case microphonePermissionDenied
    case localeNotSupported(Locale)
    case noCompatibleAudioFormat
    case audioConversionFailed
}

/// Live transcription backed by SpeechAnalyzer + SpeechTranscriber (volatile results).
///
/// `startListening` cannot throw, so every failure (permission, unsupported locale, model
/// install, audio engine, analyzer) is published on `errors`. Failures finish the transcript
/// stream. Consume `errors` for the lifetime of the object; it is a single-consumer stream.
final class SpeechAnalyzerSpeechToText: SpeechToText {
    let errors: AsyncStream<any Error>
    private let errorContinuation: AsyncStream<any Error>.Continuation
    private let session = Session()

    init() {
        (errors, errorContinuation) = AsyncStream.makeStream()
    }

    deinit {
        errorContinuation.finish()
    }

    func startListening(locale: Locale) -> AsyncStream<TranscriptUpdate> {
        let (stream, continuation) = AsyncStream<TranscriptUpdate>.makeStream()
        let errorContinuation = errorContinuation
        let session = session
        Task {
            do {
                try await session.start(locale: locale, updates: continuation)
            } catch is CancellationError {
                continuation.finish()
            } catch {
                errorContinuation.yield(error)
                continuation.finish()
            }
        }
        return stream
    }

    func stopListening() async {
        do {
            try await session.stop()
        } catch {
            errorContinuation.yield(error)
        }
    }
}

/// Transcript text and mic level shared between the realtime tap and the results task.
private final class SharedTranscript: Sendable {
    private struct State {
        var committed = ""
        var volatile = ""
        var alternatives: [String] = []
        var level: Float = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var level: Float { state.withLock { $0.level } }
    var alternatives: [String] { state.withLock { $0.alternatives } }

    func update(_ text: String, alternatives: [String], isFinal: Bool) {
        state.withLock { state in
            let committed = state.committed
            state.alternatives = alternatives.map { committed + $0 }
            if isFinal {
                state.committed += text
                state.volatile = ""
            } else {
                state.volatile = text
            }
        }
    }

    func setLevel(_ level: Float) { state.withLock { $0.level = level } }

    func snapshot(level: Float? = nil, isFinal: Bool = false) -> TranscriptUpdate {
        state.withLock {
            TranscriptUpdate(text: $0.committed + $0.volatile, isFinal: isFinal, level: level ?? $0.level, alternatives: $0.alternatives)
        }
    }
}

/// Used only from the audio tap thread, which delivers buffers serially.
private final class TapConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init?(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return nil }
        self.converter = converter
        self.outputFormat = outputFormat
    }

    func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw SpeechToTextError.audioConversionFailed
        }
        nonisolated(unsafe) var consumed = false
        nonisolated(unsafe) let input = buffer
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return input
        }
        if status == .error { throw conversionError ?? SpeechToTextError.audioConversionFailed }
        return output
    }
}

private actor Session {
    private static let logger = Logger(subsystem: "Hablemos", category: "SpeechToText")

    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, any Error>?
    private var updates: AsyncStream<TranscriptUpdate>.Continuation?
    private var shared = SharedTranscript()
    private var stopRequested = false

    func start(locale: Locale, updates: AsyncStream<TranscriptUpdate>.Continuation) async throws {
        await teardownRunning()
        stopRequested = false
        self.updates = updates
        do {
            try await configureAndRun(locale: locale, updates: updates)
        } catch {
            await abort()
            throw error
        }
    }

    func stop() async throws {
        stopRequested = true
        guard let analyzer else { return }
        stopCapture()
        let results = resultsTask
        let updates = updates
        let shared = shared
        self.analyzer = nil
        resultsTask = nil
        self.updates = nil
        defer {
            updates?.yield(shared.snapshot(level: 0, isFinal: true))
            updates?.finish()
        }
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await results?.value
        await deactivateAudioSession()
    }

    private func configureAndRun(locale: Locale, updates: AsyncStream<TranscriptUpdate>.Continuation) async throws {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw SpeechToTextError.microphonePermissionDenied
        }
        try checkNotStopped()

        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechToTextError.localeNotSupported(locale)
        }
        let transcriber = SpeechTranscriber(
            locale: supported,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .alternativeTranscriptions],
            attributeOptions: []
        )
        try await installModelIfNeeded(for: transcriber, locale: supported)
        try checkNotStopped()

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw SpeechToTextError.noCompatibleAudioFormat
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try checkNotStopped()

        let (inputSequence, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = inputContinuation
        let shared = SharedTranscript()
        self.shared = shared

        resultsTask = Task {
            for try await result in transcriber.results {
                shared.update(
                    String(result.text.characters),
                    alternatives: result.alternatives.map { String($0.characters) },
                    isFinal: result.isFinal
                )
                updates.yield(shared.snapshot())
            }
        }

        try activateAudioSession()
        let engine = AVAudioEngine()
        self.engine = engine
        try installTap(on: engine, analyzerFormat: analyzerFormat, input: inputContinuation, shared: shared, updates: updates)
        try await analyzer.start(inputSequence: inputSequence)
        engine.prepare()
        try engine.start()
        try checkNotStopped()
    }

    private func installModelIfNeeded(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let installed = await SpeechTranscriber.installedLocales
        if !installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        }
        try await AssetInventory.reserve(locale: locale)
    }

    private func installTap(
        on engine: AVAudioEngine,
        analyzerFormat: AVAudioFormat,
        input: AsyncStream<AnalyzerInput>.Continuation,
        shared: SharedTranscript,
        updates: AsyncStream<TranscriptUpdate>.Continuation
    ) throws {
        let inputNode = engine.inputNode
        let micFormat = inputNode.outputFormat(forBus: 0)
        guard let converter = TapConverter(from: micFormat, to: analyzerFormat) else {
            throw SpeechToTextError.audioConversionFailed
        }
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
            shared.setLevel(AudioLevel.normalizedRMS(of: buffer))
            do {
                input.yield(AnalyzerInput(buffer: try converter.convert(buffer)))
            } catch {
                Self.logger.error("Audio conversion failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            updates.yield(shared.snapshot())
        }
    }

    private func checkNotStopped() throws {
        if stopRequested { throw CancellationError() }
    }

    private func activateAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try audioSession.setActive(true)
    }

    private func deactivateAudioSession() async {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopCapture() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        inputContinuation?.finish()
        inputContinuation = nil
    }

    private func teardownRunning() async {
        guard analyzer != nil else { return }
        try? await stop()
    }

    /// Start failed or was cancelled midway: release everything without finalizing.
    private func abort() async {
        stopCapture()
        resultsTask?.cancel()
        resultsTask = nil
        await analyzer?.cancelAndFinishNow()
        analyzer = nil
        updates = nil
    }
}
