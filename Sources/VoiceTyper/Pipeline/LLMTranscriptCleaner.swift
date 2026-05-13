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

    static let gemmaModelID = "mlx-community/gemma-3-1b-it-4bit"
    static let gemmaFolderName = "gemma-3-1b-it-4bit"
    static let gemmaStoragePath = "\(NSHomeDirectory())/Library/Application Support/NeelSpeak/Models/MLX"

    private(set) var engine: CleanupEngine = .foundationModels
    private(set) var state: LoadState = .unloaded
    private var gemmaContainer: ModelContainer?
    private var foundationModelsPrewarmed = false

    func currentState() -> LoadState { state }
    func currentEngine() -> CleanupEngine { engine }

    func setEngine(_ newEngine: CleanupEngine) async {
        guard newEngine != engine else { return }
        engine = newEngine
        gemmaContainer = nil
        state = .unloaded
    }

    static func mlxMetallibAvailable() -> Bool {
        let fm = FileManager.default
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/mlx-swift_Cmlx.bundle/default.metallib"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/mlx.metallib"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/mlx.metallib")
        ]
        return candidates.contains { fm.fileExists(atPath: $0.path) }
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
                // Pre-warm the model so the first dictation doesn't pay cold-start cost.
                if !foundationModelsPrewarmed {
                    let warmupSession = LanguageModelSession(instructions: { "You clean speech-to-text transcripts." })
                    warmupSession.prewarm()
                    foundationModelsPrewarmed = true
                    cleanerLog.info("FoundationModels prewarmed")
                }
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
        guard Self.mlxMetallibAvailable() else {
            cleanerLog.error("prepareGemma: MLX metallib not bundled — Xcode build required")
            state = .unsupported("Gemma needs the app to be built with full Xcode. Install Xcode and run Scripts/redeploy-app.sh.")
            return
        }
        cleanerLog.info("prepareGemma: starting download/load")
        state = .downloading(0)
        progress(0)

        do {
            try FileManager.default.createDirectory(
                atPath: Self.gemmaStoragePath,
                withIntermediateDirectories: true
            )

            let hub = HubApi(downloadBase: URL(fileURLWithPath: Self.gemmaStoragePath))
            let configuration = ModelConfiguration(
                id: Self.gemmaModelID,
                extraEOSTokens: ["<end_of_turn>", "<eos>"]
            )

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

        // Fast path: if conservative mode and the transcript shows no disfluencies,
        // skip the LLM call entirely. Saves 0.5-2s per dictation on clean speech.
        if mode == .conservative && Self.looksClean(trimmed) {
            cleanerLog.info("clean: fast-path bypass (no disfluencies detected)")
            return trimmed
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

    /// Returns true if the text shows no obvious markers Conservative mode would clean.
    /// Used to skip the LLM entirely for already-clean speech (most short utterances).
    private static func looksClean(_ text: String) -> Bool {
        let patterns = [
            // Filler words / phrases (case-insensitive, whole-word)
            #"(?i)\b(?:um+|uh+|er+|erm|ah+|like|you know|sort of|kind of|i mean)\b"#,
            // Stutters: "I-I", "th-the"
            #"(?i)\b(\w{1,3})-\1?\w*\b"#,
            // Exact word repetitions: "the the cat"
            #"(?i)\b(\w+)\s+\1\b"#
        ]
        for p in patterns {
            if text.range(of: p, options: .regularExpression) != nil {
                return false
            }
        }
        return true
    }

    private func cleanWithFoundationModels(_ text: String, mode: CleanupMode) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            do {
                let instructions = "You are a transcript editor. You return only the cleaned transcript with no preface, no commentary, no quotes."
                let session = LanguageModelSession(instructions: { instructions })

                let prompt = Self.foundationModelsPrompt(for: text, mode: mode)
                let maxTokens = max(32, min(192, text.count / 3 + 32))
                let options = GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.0,
                    maximumResponseTokens: maxTokens
                )
                let response = try await session.respond(to: prompt, options: options)
                let output = sanitizeOutput(response.content, original: text)
                return output.isEmpty ? nil : output
            } catch {
                cleanerLog.error("cleanWithFoundationModels failed: \(String(describing: error))")
                return nil
            }
        }
        #endif
        return nil
    }

    private static func foundationModelsPrompt(for text: String, mode: CleanupMode) -> String {
        switch mode {
        case .off:
            return text
        case .conservative:
            return """
            TASK: Delete fillers and disfluencies from the transcript below. Keep everything else exactly. Output the cleaned transcript only.

            DELETE these words/phrases anywhere they appear (case-insensitive): "um", "umm", "uh", "uhh", "uhm", "uh oh", "er", "erm", "ah", "well" (when used as a hesitation), "like" (when used as a filler), "you know", "I mean", "sort of", "kind of".

            DELETE these patterns:
            - Stutters: "I-I", "th-the", "wa-wait"
            - Exact word repetitions: "the the cat" → "the cat"
            - Course corrections: keep only the corrected phrase. Example: "go to the store, I mean the market" → "go to the market"

            KEEP all other words exactly as written. Apply capitalization and end-of-sentence punctuation. Do not paraphrase. Do not add new content.

            EXAMPLE 1
            Transcript: um so like i went to the the store yesterday you know
            Cleaned: I went to the store yesterday.

            EXAMPLE 2
            Transcript: send the email to John uh I mean to Sarah by Friday
            Cleaned: Send the email to Sarah by Friday.

            EXAMPLE 3
            Transcript: hi i am recording uh oh well uh i am just testing this
            Cleaned: Hi, I am recording. I am just testing this.

            Transcript: \(text)
            Cleaned:
            """
        case .aggressive:
            return """
            TASK: Clean and lightly edit the transcript below. Output the cleaned transcript only.

            DELETE fillers: "um", "uh", "er", "ah", "well", "like", "you know", "I mean", "sort of", "kind of", "uh oh".
            DELETE stutters and exact repetitions.
            RESOLVE course corrections (keep only the corrected phrase).
            TIGHTEN run-on sentences with sensible punctuation.
            FIX obvious grammar slips that come from spoken word order.

            Do not invent information. Do not add commentary. Preserve the speaker's voice.

            EXAMPLE 1
            Transcript: so I went to the store um and I was gonna get milk but like I forgot my wallet so I had to go back home
            Cleaned: I went to the store to get milk, but I forgot my wallet, so I had to go back home.

            EXAMPLE 2
            Transcript: the the meeting it's at three I think yeah three o'clock tomorrow
            Cleaned: The meeting is at three o'clock tomorrow.

            Transcript: \(text)
            Cleaned:
            """
        }
    }

    private func cleanWithGemma(_ text: String, mode: CleanupMode) async -> String? {
        guard let container = gemmaContainer else { return nil }
        do {
            var messages: [[String: String]] = [
                ["role": "system", "content": mode.systemPrompt]
            ]
            for (input, output) in mode.fewShotExamples {
                messages.append(["role": "user", "content": input])
                messages.append(["role": "assistant", "content": output])
            }
            messages.append(["role": "user", "content": text])

            let userInput = UserInput(messages: messages)
            let maxTokens = estimatedMaxOutputTokens(for: text)
            let result = try await container.perform { context in
                let lmInput = try await context.processor.prepare(input: userInput)
                let parameters = GenerateParameters(temperature: 0.1)
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
        var output = raw

        // Strip chat-template control tokens that sometimes leak into decoded text.
        let stripTokens = [
            "<end_of_turn>", "<start_of_turn>", "<eos>", "<bos>",
            "<|im_end|>", "<|im_start|>", "<|end|>", "<|start|>",
            "<|user|>", "<|assistant|>", "<|system|>"
        ]
        for token in stripTokens {
            output = output.replacingOccurrences(of: token, with: "")
        }

        // Cut off at any role marker the model might emit when it tries to start
        // a new turn (defensive — chat template usually prevents this).
        for marker in ["\nuser:", "\nassistant:", "\nUser:", "\nAssistant:"] {
            if let range = output.range(of: marker) {
                output = String(output[..<range.lowerBound])
            }
        }

        output = output.trimmingCharacters(in: .whitespacesAndNewlines)

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
