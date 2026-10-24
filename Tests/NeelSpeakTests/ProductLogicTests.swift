import Testing
@testable import VoiceTyper

struct UpdateCheckerTests {
    @Test(arguments: [
        ("1.0.0", "0.2.1", true),
        ("1.0.1", "1.0.0", true),
        ("1.10.0", "1.9.3", true),
        ("1.0", "1.0.0", false),
        ("1.0.0", "1.0.0", false),
        ("0.9.9", "1.0.0", false),
        ("2.0.0-beta", "1.9.0", true),
    ])
    func comparesVersions(_ candidate: String, _ current: String, _ newer: Bool) {
        #expect(UpdateChecker.isVersion(candidate, newerThan: current) == newer)
    }
}

struct AnthropicRequestShapeTests {
    @Test(arguments: [
        "claude-haiku-4-5", "claude-sonnet-4-6", "claude-opus-4-1", "claude-sonnet-4-20250514",
        "claude-3-5-haiku-latest", "claude-opus-4-0",
    ])
    func legacyModelsKeepTemperature(_ model: String) {
        #expect(CloudCleanupService.anthropicModelAcceptsTemperature(model))
    }

    @Test(arguments: [
        "claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-4-7", "claude-opus-4-8", "claude-opus-5", "claude-fable-5-1",
    ])
    func currentModelsOmitTemperature(_ model: String) {
        #expect(!CloudCleanupService.anthropicModelAcceptsTemperature(model))
    }

    @Test func extractsProviderErrorMessages() {
        #expect(CloudCleanupService.providerMessage(in: #"{"type":"error","error":{"type":"invalid_request_error","message":"bad key"}}"#) == "bad key")
        #expect(CloudCleanupService.providerMessage(in: #"{"error":{"message":"Unsupported value: 'temperature'"}}"#) == "Unsupported value: 'temperature'")
        #expect(CloudCleanupService.providerMessage(in: "not json") == nil)
    }
}
