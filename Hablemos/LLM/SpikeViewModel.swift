import Foundation
import HablemosCore
import Observation
import os

@MainActor
@Observable
final class SpikeViewModel {
    private(set) var log: [String] = []
    private(set) var isRunning = false
    private(set) var reply = ""

    private let host: LiteRTEngineHost

    init(host: LiteRTEngineHost) {
        self.host = host
    }

    func run(variant: ModelVariant) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        reply = ""
        record("model: \(variant.rawValue) installed=\(ModelStore.isInstalled(variant)) size=\(ModelStore.installedSize(of: variant) ?? 0)")
        record("memory before load: \(Self.footprintMB()) MB, available: \(Self.availableMB()) MB")

        do {
            let loadStart = Date()
            try await host.load(variant)
            record("engine loaded in \(String(format: "%.1f", Date().timeIntervalSince(loadStart))) s")
            record("memory after load: \(Self.footprintMB()) MB, available: \(Self.availableMB()) MB")

            let model = LiteRTLanguageModel(host: host)
            let system = "You are Lucía, a friendly barista in Madrid. Reply ONLY in Spanish, 2 short sentences max, present tense only. End with a question."
            let start = Date()
            var firstChunk: Date?
            var chunks = 0
            var characters = 0
            var cumulativeChunks = 0
            for try await chunk in model.stream(system: system, history: [], user: "Hola, quiero un café con leche, por favor.") {
                if firstChunk == nil {
                    firstChunk = Date()
                    record("first chunk after \(String(format: "%.2f", firstChunk!.timeIntervalSince(start))) s")
                }
                chunks += 1
                characters += chunk.count
                if !reply.isEmpty, chunk.hasPrefix(reply) { cumulativeChunks += 1 }
                reply += chunk
            }
            let decodeSeconds = Date().timeIntervalSince(firstChunk ?? start)
            record("reply: \(reply.replacingOccurrences(of: "\n", with: " "))")
            record("chunks=\(chunks) chars=\(characters) cumulativeLooking=\(cumulativeChunks) total=\(String(format: "%.2f", Date().timeIntervalSince(start))) s")
            record("chunks/sec ≈ \(String(format: "%.1f", Double(chunks) / max(decodeSeconds, 0.001))) (tokens/sec ≈ chunks/sec if one token per chunk)")
            record("memory after reply: \(Self.footprintMB()) MB, available: \(Self.availableMB()) MB")
            let transcript = [
                ChatMessage(role: .tutor, text: "¡Hola! Bienvenido al café. ¿Qué te pongo?"),
                ChatMessage(role: .user, text: "Quiero una café con leche por favor."),
                ChatMessage(role: .tutor, text: "Claro. ¿Algo más?"),
                ChatMessage(role: .user, text: "El cruasán es muy rico."),
            ]
            let jsonStart = Date()
            let raw = try await model.completeJSON(prompt: SessionSummaryPrompt.make(transcript: transcript), jsonSchema: SessionSummary.jsonSchema)
            record("summary json in \(String(format: "%.1f", Date().timeIntervalSince(jsonStart))) s: \(raw.replacingOccurrences(of: "\n", with: " "))")
            let parsed = try SessionSummaryParser.parse(raw)
            record("summary parsed: \(parsed.mistakes.count) mistakes, level \(parsed.estimatedLevel.rawValue)")
            record("SPIKE OK")
        } catch {
            record("SPIKE FAILED: \(error)")
        }
    }

    private func record(_ line: String) {
        log.append(line)
        print("[spike] \(line)")
    }

    static func footprintMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : -1
    }

    static func availableMB() -> Int {
        Int(os_proc_available_memory() / 1_048_576)
    }
}
