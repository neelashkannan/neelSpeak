import Foundation
import os

private let cloudLog = Logger(subsystem: "com.neelspeak.app", category: "cloud-cleanup")

/// Stateless HTTP client that calls cloud LLM providers for transcript cleanup.
/// Used by `LLMTranscriptCleaner` when the user selects `openAICompatible` or
/// `anthropic` as the engine.
enum CloudCleanupService {

    enum Error: Swift.Error, CustomStringConvertible {
        case missingApiKey
        case badResponse(Int, String)
        case decoding(String)
        case other(String)

        var description: String {
            switch self {
            case .missingApiKey:
                return "API key not configured. Open NeelSpeak settings and paste your key."
            case .badResponse(let code, let body):
                return "HTTP \(code): \(body.prefix(200))"
            case .decoding(let msg):
                return "Decode error: \(msg)"
            case .other(let msg):
                return msg
            }
        }
    }

    // MARK: - OpenAI-compatible

    /// POST `/chat/completions` against any OpenAI-compatible endpoint.
    /// Works with: OpenAI direct, GitHub Models, OpenRouter, Groq, Together,
    /// local Ollama (http://localhost:11434/v1), etc.
    static func cleanWithOpenAICompatible(
        text: String,
        mode: CleanupMode,
        baseURL: String,
        apiKey: String,
        model: String
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw Error.missingApiKey }

        let url = try buildURL(baseURL: baseURL, path: "/chat/completions")
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.1,
            "max_tokens": maxOutputTokens(for: text),
            "messages": [
                ["role": "system", "content": mode.systemPrompt],
                ["role": "user", "content": text]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let started = Date()
        let (data, resp) = try await URLSession.shared.data(for: req)
        let elapsed = Date().timeIntervalSince(started)
        guard let http = resp as? HTTPURLResponse else {
            throw Error.other("Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.badResponse(http.statusCode, body)
        }

        // OpenAI shape: { choices: [ { message: { content: "..." } } ] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.decoding("Unexpected JSON shape: \(body.prefix(200))")
        }
        cloudLog.info("openai-compat \(model, privacy: .public) \(elapsed, format: .fixed(precision: 2))s")
        return content
    }

    // MARK: - GitHub Copilot

    /// POST `/chat/completions` against the GitHub Copilot Chat API.
    /// `sessionToken` is the short-lived Copilot token from
    /// `CopilotAuthService.fetchSessionToken(oauthToken:)`.
    static func cleanWithCopilot(
        text: String,
        mode: CleanupMode,
        sessionToken: String,
        model: String
    ) async throws -> String {
        guard let url = URL(string: "https://api.githubcopilot.com/chat/completions") else {
            throw Error.other("Bad Copilot URL")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        // Copilot's gateway sniffs editor headers — without them it refuses requests.
        req.setValue("vscode/1.95.0", forHTTPHeaderField: "Editor-Version")
        req.setValue("copilot-chat/0.22.0", forHTTPHeaderField: "Editor-Plugin-Version")
        req.setValue("GithubCopilot/1.155.0", forHTTPHeaderField: "User-Agent")
        req.setValue("2025-01-01", forHTTPHeaderField: "Openai-Intent")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.1,
            "max_tokens": maxOutputTokens(for: text),
            "messages": [
                ["role": "system", "content": mode.systemPrompt],
                ["role": "user", "content": text]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let started = Date()
        let (data, resp) = try await URLSession.shared.data(for: req)
        let elapsed = Date().timeIntervalSince(started)
        guard let http = resp as? HTTPURLResponse else { throw Error.other("Non-HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.badResponse(http.statusCode, body)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.decoding("Unexpected JSON: \(body.prefix(200))")
        }
        cloudLog.info("copilot \(model, privacy: .public) \(elapsed, format: .fixed(precision: 2))s")
        return content
    }

    /// GET `/models` on the Copilot endpoint. Returns chat-capable model ids
    /// available to this user's Copilot subscription.
    static func fetchCopilotModels(sessionToken: String) async throws -> [String] {
        guard let url = URL(string: "https://api.githubcopilot.com/models") else {
            throw Error.other("Bad Copilot URL")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "GET"
        req.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        req.setValue("vscode/1.95.0", forHTTPHeaderField: "Editor-Version")
        req.setValue("copilot-chat/0.22.0", forHTTPHeaderField: "Editor-Plugin-Version")
        req.setValue("GithubCopilot/1.155.0", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw Error.other("Non-HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.badResponse(http.statusCode, body)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.decoding("Unexpected models JSON: \(body.prefix(200))")
        }

        // Filter for chat-capable, model-picker-enabled models.
        var ids: [String] = []
        for item in items {
            guard let id = item["id"] as? String else { continue }
            // Exclude embedding-only / completion-only models when capabilities are reported.
            if let caps = item["capabilities"] as? [String: Any],
               let type = caps["type"] as? String,
               type != "chat" {
                continue
            }
            // Honor model_picker_enabled when present
            if let picker = item["model_picker_enabled"] as? Bool, !picker {
                continue
            }
            ids.append(id)
        }
        return ids.sorted()
    }

    // MARK: - Anthropic

    /// POST `/v1/messages` against Anthropic's API.
    static func cleanWithAnthropic(
        text: String,
        mode: CleanupMode,
        apiKey: String,
        model: String
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw Error.missingApiKey }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw Error.other("Bad Anthropic URL")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxOutputTokens(for: text),
            "temperature": 0.1,
            "system": mode.systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let started = Date()
        let (data, resp) = try await URLSession.shared.data(for: req)
        let elapsed = Date().timeIntervalSince(started)
        guard let http = resp as? HTTPURLResponse else {
            throw Error.other("Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.badResponse(http.statusCode, body)
        }

        // Anthropic shape: { content: [ { type: "text", text: "..." } ] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Error.decoding("Unexpected JSON shape: \(body.prefix(200))")
        }
        cloudLog.info("anthropic \(model, privacy: .public) \(elapsed, format: .fixed(precision: 2))s")
        return firstText
    }

    // MARK: - Helpers

    private static func buildURL(baseURL: String, path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)\(path)") else {
            throw Error.other("Bad base URL: \(baseURL)")
        }
        return url
    }

    private static func maxOutputTokens(for text: String) -> Int {
        max(64, min(384, text.count / 3 + 64))
    }
}

/// Provider presets for the OpenAI-compatible engine. Each gives a sensible
/// default base URL and model so users can pick a known provider without
/// remembering the exact URL.
struct OpenAICompatPreset: Identifiable, Hashable {
    let id: String
    let displayName: String
    let baseURL: String
    let defaultModel: String
    let apiKeyHint: String

    static let openai = OpenAICompatPreset(
        id: "openai",
        displayName: "OpenAI",
        baseURL: "https://api.openai.com/v1",
        defaultModel: "gpt-4o-mini",
        apiKeyHint: "sk-... from platform.openai.com"
    )

    static let githubModels = OpenAICompatPreset(
        id: "github-models",
        displayName: "GitHub Models (free)",
        baseURL: "https://models.github.ai/inference",
        defaultModel: "openai/gpt-4o-mini",
        apiKeyHint: "GitHub PAT (no scopes needed) from github.com/settings/tokens"
    )

    static let openRouter = OpenAICompatPreset(
        id: "openrouter",
        displayName: "OpenRouter",
        baseURL: "https://openrouter.ai/api/v1",
        defaultModel: "openai/gpt-4o-mini",
        apiKeyHint: "sk-or-... from openrouter.ai/keys"
    )

    static let groq = OpenAICompatPreset(
        id: "groq",
        displayName: "Groq (fast)",
        baseURL: "https://api.groq.com/openai/v1",
        defaultModel: "llama-3.3-70b-versatile",
        apiKeyHint: "gsk_... from console.groq.com"
    )

    static let ollama = OpenAICompatPreset(
        id: "ollama",
        displayName: "Ollama (local)",
        baseURL: "http://localhost:11434/v1",
        defaultModel: "llama3.2:3b",
        apiKeyHint: "Any value (Ollama ignores it). Run: ollama pull llama3.2:3b"
    )

    static let opencode = OpenAICompatPreset(
        id: "opencode",
        displayName: "OpenCode (local server)",
        baseURL: "http://localhost:4096/v1",
        defaultModel: "anthropic/claude-haiku-4-5",
        apiKeyHint: "Run: opencode serve. Uses providers configured in your opencode config. Key value is ignored."
    )

    static let custom = OpenAICompatPreset(
        id: "custom",
        displayName: "Custom",
        baseURL: "",
        defaultModel: "",
        apiKeyHint: ""
    )

    static let all: [OpenAICompatPreset] = [.githubModels, .openai, .openRouter, .groq, .ollama, .opencode, .custom]
}
