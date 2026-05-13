import Foundation
import Hub
import MLXLLM
import MLXLMCommon
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

private let cleanerLog = Logger(subsystem: "com.neelspeak.app", category: "cleanup")

actor LLMTranscriptCleaner {
    enum LoadState: Equatable {
        case unloaded
        case downloading(Double)
        case loading
        case ready
        case unsupported(String)
        case failed(String)
    }

    static let gemmaModelID = "mlx-community/gemma-3-4b-it-4bit"
    static let gemmaFolderName = "gemma-3-4b-it-4bit"
    static let gemmaStoragePath = "\(NSHomeDirectory())/Library/Application Support/NeelSpeak/Models/MLX"

    private(set) var engine: CleanupEngine = .foundationModels
    private(set) var state: LoadState = .unloaded
    private var gemmaContainer: ModelContainer?

    func currentState() -> LoadState { state }
    func currentEngine() -> CleanupEngine { engine }

    func setEngine(_ newEngine: CleanupEngine) async {
        guard newEngine != engine else { return }
        engine = newEngine
        gemmaContainer = nil
        state = .unloaded
    }

    func gemmaInstalled() -> Bool {
        let snapshot = URL(fileURLWithPath: Self.gemmaStoragePath)
            .appendingPathComponent("models")
            .appendingPathComponent("mlx-community")
            .appendingPathComponent(Self.gemmaFolderName)
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: snapshot.path) else {
            return false
        }
        return entries.contains { $0.hasSuffix(".safetensors") }
    }

    func prepare(progress: @escaping @Sendable (Double) -> Void) async {
        if case .ready = state { return }
        if case .loading = state { return }
        if case .downloading = state { return }

        switch engine {
        case .foundationModels:
            await prepareFoundationModels()
        case .gemma:
            await prepareGemma(progress: progress)
        }
    }

    private func prepareFoundationModels() async {
        cleanerLog.info("prepareFoundationModels: checking availability")
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            switch availability {
            case .available:
                cleanerLog.info("FoundationModels available, marking ready")
                state = .ready
            case .unavailable(let reason):
                cleanerLog.error("FoundationModels unavailable: \(String(describing: reason))")
                state = .unsupported("Apple Intelligence unavailable: \(String(describing: reason))")
            }
            return
        }
        #endif
        cleanerLog.error("FoundationModels not compiled in / macOS too old")
        state = .unsupported("Apple Intelligence requires macOS 26 or later.")
    }

    private func prepareGemma(progress: @escaping @Sendable (Double) -> Void) async {
        cleanerLog.info("prepareGemma: starting download/load")
        state = .downloading(0)
        progress(0)

        do {
            try FileManager.default.createDirectory(
                atPath: Self.gemmaStoragePath,
                withIntermediateDirectories: true
            )

            let hub = HubApi(downloadBase: URL(fileURLWithPath: Self.gemmaStoragePath))
            let configuration = ModelConfiguration(id: Self.gemmaModelID)

            let loaded = try await LLMModelFactory.shared.loadContainer(
                hub: hub,
                configuration: configuration
            ) { p in
                let fraction = max(0, min(1, p.fractionCompleted))
                progress(fraction)
            }

            cleanerLog.info("prepareGemma: download done, loading container")
            state = .loading
            gemmaContainer = loaded
            cleanerLog.info("prepareGemma: ready")
            state = .ready
        } catch {
            cleanerLog.error("prepareGemma failed: \(String(describing: error))")
            gemmaContainer = nil
            state = .failed(String(describing: error))
        }
    }

    func unload() {
        gemmaContainer = nil
        state = .unloaded
    }

    func clean(_ text: String, mode: CleanupMode) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mode != .off, !trimmed.isEmpty else { return text }
        guard case .ready = state else {
            cleanerLog.info("clean called but state not ready, returning raw text")
            return text
        }

        let started = Date()
        let result: String
        switch engine {
        case .foundationModels:
            result = await cleanWithFoundationModels(trimmed, mode: mode) ?? text
        case .gemma:
            result = await cleanWithGemma(trimmed, mode: mode) ?? text
        }
        let elapsed = Date().timeIntervalSince(started)
        cleanerLog.info("clean(\(self.engine.rawValue, privacy: .public), \(mode.rawValue, privacy: .public)) took \(elapsed, format: .fixed(precision: 2))s")
        return result
    }

    private func cleanWithFoundationModels(_ text: String, mode: CleanupMode) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: { mode.systemPrompt })
                let options = GenerationOptions(temperature: 0.2)
                let response = try await session.respond(to: text, options: options)
                let output = sanitizeOutput(response.content, original: text)
                return output.isEmpty ? nil : output
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    private func cleanWithGemma(_ text: String, mode: CleanupMode) async -> String? {
        guard let container = gemmaContainer else { return nil }
        do {
            let userInput = UserInput(messages: [
                ["role": "system", "content": mode.systemPrompt],
                ["role": "user", "content": text]
            ])

            let maxTokens = estimatedMaxOutputTokens(for: text)
            let result = try await container.perform { context in
                let lmInput = try await context.processor.prepare(input: userInput)
                let parameters = GenerateParameters(temperature: 0.2)
                return try MLXLMCommon.generate(
                    input: lmInput,
                    parameters: parameters,
                    context: context
                ) { tokens in
                    tokens.count >= maxTokens ? .stop : .more
                }
            }

            let cleaned = sanitizeOutput(result.output, original: text)
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }

    private func estimatedMaxOutputTokens(for text: String) -> Int {
        let approxTokens = max(64, text.count / 3)
        return min(512, approxTokens + 64)
    }

    private func sanitizeOutput(_ raw: String, original: String) -> String {
        var output = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.hasPrefix("\"") && output.hasSuffix("\"") && output.count >= 2 {
            output = String(output.dropFirst().dropLast())
        }
        if output.hasPrefix("'") && output.hasSuffix("'") && output.count >= 2 {
            output = String(output.dropFirst().dropLast())
        }
        let lowered = output.lowercased()
        for prefix in ["output:", "cleaned:", "cleaned transcript:", "result:"] {
            if lowered.hasPrefix(prefix) {
                output = String(output.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
