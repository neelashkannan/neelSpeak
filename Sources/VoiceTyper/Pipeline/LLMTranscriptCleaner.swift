import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

private let cleanerLog = Logger(subsystem: "com.neelspeak.app", category: "cleanup")

actor LLMTranscriptCleaner {
    enum LoadState: Equatable {
        case unloaded
        case loading
        case ready
        case unsupported(String)
        case failed(String)
    }

    /// What `clean` produced. `issue` is set when cleanup was requested but
    /// the raw transcript had to be used instead, so the UI can say why.
    struct CleanupResult: Sendable {
        let text: String
        let issue: String?
    }

    struct CloudConfig: Sendable, Equatable {
        static let defaultAnthropicModel = "claude-haiku-5-5"

        var openAIBaseURL: String = OpenAICompatPreset.githubModels.baseURL
        var openAIModel: String = OpenAICompatPreset.githubModels.defaultModel
        var openAIKey: String = ""
        var anthropicModel: String = defaultAnthropicModel
        var anthropicKey: String = ""
        var copilotModel: String = "gpt-4o-mini"
        var copilotOAuthToken: String = ""  // ghu_... from device flow
    }

    private(set) var engine: CleanupEngine = .foundationModels
    private(set) var state: LoadState = .unloaded
    private var foundationModelsPrewarmed = false
    private var cloudConfig = CloudConfig()
    private var copilotSessionToken: String?
    private var copilotSessionExpiry: Date?

    func currentState() -> LoadState { state }
    func currentEngine() -> CleanupEngine { engine }

    func setEngine(_ newEngine: CleanupEngine) async {
        guard newEngine != engine else { return }
        engine = newEngine
        state = .unloaded
    }

    func setCloudConfig(_ config: CloudConfig) {
        guard config != cloudConfig else { return }
        if config.copilotOAuthToken != cloudConfig.copilotOAuthToken {
            copilotSessionToken = nil
            copilotSessionExpiry = nil
        }
        cloudConfig = config
        // Keys or models changed: the engine has to be checked again.
        if engine.isCloud { state = .unloaded }
    }

    func prepare(progress: @escaping @Sendable (Double) -> Void) async {
        if case .ready = state { return }
        if case .loading = state { return }

        switch engine {
        case .foundationModels:
            await prepareFoundationModels()
        case .openAICompatible:
            prepareOpenAICompatible()
        case .anthropic:
            prepareAnthropic()
        case .githubCopilot:
            await prepareCopilot()
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
        state = .unsupported("Apple Intelligence requires macOS 26 or later.")
    }

    private func prepareOpenAICompatible() {
        state = cloudConfig.openAIKey.isEmpty
            ? .unsupported("Set an OpenAI-compatible API key in NeelSpeak settings.")
            : .ready
    }

    private func prepareAnthropic() {
        state = cloudConfig.anthropicKey.isEmpty
            ? .unsupported("Set an Anthropic API key in NeelSpeak settings.")
            : .ready
    }

    private func prepareCopilot() async {
        if cloudConfig.copilotOAuthToken.isEmpty {
            state = .unsupported("Sign in to GitHub Copilot in NeelSpeak settings.")
            return
        }
        // Exchange OAuth token for a short-lived Copilot session token
        do {
            state = .loading
            let session = try await CopilotAuthService.fetchSessionToken(
                oauthToken: cloudConfig.copilotOAuthToken
            )
            copilotSessionToken = session.token
            copilotSessionExpiry = session.expiresAt
            state = .ready
            cleanerLog.info("Copilot session token ready, expires \(session.expiresAt, privacy: .public)")
        } catch {
            cleanerLog.error("Copilot prepare failed: \(String(describing: error))")
            state = .failed(String(describing: error))
        }
    }

    /// Returns the list of chat models this user's Copilot subscription
    /// exposes. Refreshes the session token first if needed.
    func fetchCopilotModels() async -> [String] {
        guard !cloudConfig.copilotOAuthToken.isEmpty else { return [] }
        do {
            if copilotSessionToken == nil || (copilotSessionExpiry ?? Date.distantPast) < Date().addingTimeInterval(60) {
                let session = try await CopilotAuthService.fetchSessionToken(
                    oauthToken: cloudConfig.copilotOAuthToken
                )
                copilotSessionToken = session.token
                copilotSessionExpiry = session.expiresAt
            }
            guard let token = copilotSessionToken else { return [] }
            return try await CloudCleanupService.fetchCopilotModels(sessionToken: token)
        } catch {
            cleanerLog.error("fetchCopilotModels failed: \(String(describing: error))")
            return []
        }
    }

    func unload() {
        state = .unloaded
        copilotSessionToken = nil
        copilotSessionExpiry = nil
    }

    /// `allowShortcut` skips the model for transcripts with no obvious
    /// disfluencies in conservative mode; tests turn it off to hit the engine.
    func clean(_ text: String, mode: CleanupMode, allowShortcut: Bool = true) async -> CleanupResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mode != .off, !trimmed.isEmpty else { return CleanupResult(text: text, issue: nil) }
        switch state {
        case .ready:
            break
        case .unsupported(let message), .failed(let message):
            return CleanupResult(text: text, issue: message)
        case .unloaded, .loading:
            cleanerLog.info("clean called but state not ready, returning raw text")
            return CleanupResult(text: text, issue: "\(engine.displayName) wasn't ready yet.")
        }

        if allowShortcut && mode == .conservative && Self.looksClean(trimmed) {
            cleanerLog.info("clean: fast-path bypass (no disfluencies detected)")
            return CleanupResult(text: trimmed, issue: nil)
        }

        let started = Date()
        let result: CleanupResult
        do {
            let cleaned: String
            switch engine {
            case .foundationModels:
                cleaned = try await cleanWithFoundationModels(trimmed, mode: mode)
            case .openAICompatible:
                cleaned = try await cleanWithOpenAICompatible(trimmed, mode: mode)
            case .anthropic:
                cleaned = try await cleanWithAnthropic(trimmed, mode: mode)
            case .githubCopilot:
                cleaned = try await cleanWithCopilot(trimmed, mode: mode)
            }
            let sanitized = sanitizeOutput(cleaned, original: trimmed)
            result = sanitized.isEmpty
                ? CleanupResult(text: text, issue: "\(engine.displayName) returned an empty response.")
                : CleanupResult(text: sanitized, issue: nil)
        } catch {
            cleanerLog.error("clean(\(self.engine.rawValue, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
            result = CleanupResult(text: text, issue: String(describing: error))
        }
        let elapsed = Date().timeIntervalSince(started)
        cleanerLog.info("clean(\(self.engine.rawValue, privacy: .public), \(mode.rawValue, privacy: .public)) took \(elapsed, format: .fixed(precision: 2))s")
        return result
    }

    private static func looksClean(_ text: String) -> Bool {
        let patterns = [
            #"(?i)\b(?:um+|uh+|er+|erm|ah+|like|you know|sort of|kind of|i mean)\b"#,
            #"(?i)\b(\w{1,3})-\1?\w*\b"#,
            #"(?i)\b(\w+)\s+\1\b"#
        ]
        for p in patterns {
            if text.range(of: p, options: .regularExpression) != nil {
                return false
            }
        }
        return true
    }

    private func cleanWithFoundationModels(_ text: String, mode: CleanupMode) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let instructions = Self.foundationModelsInstructions(for: mode)
            let session = LanguageModelSession(instructions: { instructions })
            let prompt = "Transcript: \(text)\nCleaned:"
            let maxTokens = max(32, min(160, text.count / 3 + 24))
            #if compiler(>=6.4)
            let options = GenerationOptions(samplingMode: .greedy, temperature: 0.0, maximumResponseTokens: maxTokens)
            #else
            let options = GenerationOptions(sampling: .greedy, temperature: 0.0, maximumResponseTokens: maxTokens)
            #endif
            return try await session.respond(to: prompt, options: options).content
        }
        #endif
        throw CloudCleanupService.Error.other("Apple Intelligence requires macOS 26 or later.")
    }

    private static func foundationModelsInstructions(for mode: CleanupMode) -> String {
        switch mode {
        case .off:
            return ""
        case .conservative:
            return """
            You edit speech-to-text transcripts. Delete: um, umm, uh, uhh, uhm, uh oh, er, erm, ah, well (hesitation), like (filler), you know, I mean, sort of, kind of. Delete stutters (I-I, th-the) and exact word repetitions (the the → the). For course corrections keep only the corrected phrase. Keep all other words exactly. Apply capitalization and punctuation. Output the cleaned transcript only — no preface, no quotes.

            Transcript: um so like i went to the the store yesterday you know
            Cleaned: I went to the store yesterday.

            Transcript: hi i am recording uh oh well uh i am just testing this
            Cleaned: Hi, I am recording. I am just testing this.
            """
        case .aggressive:
            return """
            You edit speech-to-text transcripts. Delete fillers (um, uh, er, well, like, you know, I mean, sort of, kind of, uh oh), stutters, and exact repetitions. Resolve course corrections to the final phrase. Tighten run-on sentences with punctuation. Fix obvious spoken-word grammar. Do not add new info. Output cleaned transcript only.

            Transcript: so I went to the store um and I was gonna get milk but like I forgot my wallet so I had to go back home
            Cleaned: I went to the store to get milk, but I forgot my wallet, so I had to go back home.

            Transcript: the the meeting it's at three I think yeah three o'clock tomorrow
            Cleaned: The meeting is at three o'clock tomorrow.
            """
        }
    }

    private func cleanWithOpenAICompatible(_ text: String, mode: CleanupMode) async throws -> String {
        try await CloudCleanupService.cleanWithOpenAICompatible(
            text: text,
            mode: mode,
            baseURL: cloudConfig.openAIBaseURL,
            apiKey: cloudConfig.openAIKey,
            model: cloudConfig.openAIModel
        )
    }

    private func cleanWithAnthropic(_ text: String, mode: CleanupMode) async throws -> String {
        try await CloudCleanupService.cleanWithAnthropic(
            text: text,
            mode: mode,
            apiKey: cloudConfig.anthropicKey,
            model: cloudConfig.anthropicModel
        )
    }

    private func cleanWithCopilot(_ text: String, mode: CleanupMode) async throws -> String {
        // Refresh session token if expired or absent
        if copilotSessionToken == nil || (copilotSessionExpiry ?? Date.distantPast) < Date().addingTimeInterval(60) {
            let session = try await CopilotAuthService.fetchSessionToken(
                oauthToken: cloudConfig.copilotOAuthToken
            )
            copilotSessionToken = session.token
            copilotSessionExpiry = session.expiresAt
            cleanerLog.info("Refreshed Copilot session token")
        }
        guard let token = copilotSessionToken else {
            throw CloudCleanupService.Error.other("GitHub Copilot session expired. Sign in again.")
        }
        return try await CloudCleanupService.cleanWithCopilot(
            text: text,
            mode: mode,
            sessionToken: token,
            model: cloudConfig.copilotModel
        )
    }

    private func sanitizeOutput(_ raw: String, original: String) -> String {
        var output = raw

        let stripTokens = [
            "<end_of_turn>", "<start_of_turn>", "<eos>", "<bos>",
            "<|im_end|>", "<|im_start|>", "<|end|>", "<|start|>",
            "<|user|>", "<|assistant|>", "<|system|>"
        ]
        for token in stripTokens {
            output = output.replacingOccurrences(of: token, with: "")
        }

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
