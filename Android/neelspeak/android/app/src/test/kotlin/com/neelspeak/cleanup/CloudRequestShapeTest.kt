package com.neelspeak.cleanup

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CloudRequestShapeTest {
    @Test
    fun legacyClaudeModelsKeepTemperature() {
        for (model in listOf(
            "claude-3-5-haiku-latest",
            "claude-3-opus-20240229",
            "claude-2.1",
            "claude-instant-1.2",
            "claude-haiku-4-5",
            "claude-sonnet-4-5-20250929",
            "claude-opus-4-1",
            "claude-sonnet-4",
            "claude-opus-4-6",
        )) {
            assertTrue(model, AnthropicCleanupClient.acceptsTemperature(model))
        }
    }

    @Test
    fun currentClaudeModelsOmitTemperature() {
        for (model in listOf(
            "claude-haiku-5-5",
            "claude-opus-4-7",
            "claude-sonnet-5",
            "claude-opus-5-1-20260301",
            "claude-sonnet-4-8",
        )) {
            assertFalse(model, AnthropicCleanupClient.acceptsTemperature(model))
        }
    }

    @Test
    fun learnsFromTemperatureAndMaxTokensRejections() {
        val none = CloudHttp.Quirks()
        val temp = CloudHttp.adjustQuirks(
            none,
            """{"error":{"message":"Unsupported value: 'temperature' does not support 0.1 with this model."}}""",
            allowTemperatureQuirk = true,
            allowMaxTokensQuirk = true,
        )
        assertEquals(CloudHttp.Quirks(omitTemperature = true), temp)

        val tokens = CloudHttp.adjustQuirks(
            none,
            """{"error":{"message":"Unsupported parameter: 'max_tokens' is not supported with this model. Use 'max_completion_tokens' instead."}}""",
            allowTemperatureQuirk = true,
            allowMaxTokensQuirk = true,
        )
        assertEquals(CloudHttp.Quirks(useMaxCompletionTokens = true), tokens)

        // Anthropic never switches token field names.
        val anthropic = CloudHttp.adjustQuirks(
            none,
            "max_tokens: field required",
            allowTemperatureQuirk = true,
            allowMaxTokensQuirk = false,
        )
        assertEquals(none, anthropic)
    }

    @Test
    fun failureMessagesNeverCarryCredentials() {
        val message = LlmTranscriptCleaner.describeFailure(
            CleanupHttpException("The provider rejected the API key (HTTP 401). Incorrect API key provided: sk-proj-abcdef123456.")
        )
        assertFalse(message, message.contains("abcdef123456"))
        assertTrue(message, message.contains("[redacted]"))
        assertEquals(
            "token [redacted] expired",
            LlmTranscriptCleaner.redact("token ghu_0123456789abcdef expired"),
        )
    }
}
