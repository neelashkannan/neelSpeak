package com.neelspeak.cleanup

import android.util.Log
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

/**
 * Anthropic `/v1/messages` client. Mirrors `cleanWithAnthropic` in
 * Sources/VoiceTyper/Pipeline/CloudCleanupService.swift.
 */
class AnthropicCleanupClient {
    fun clean(text: String, mode: CleanupMode, apiKey: String, model: String): String {
        if (apiKey.isEmpty()) throw CleanupHttpException(
            "API key not configured. Open NeelSpeak settings and paste your key."
        )

        val messages = JSONArray()
        for ((userEx, asstEx) in mode.fewShotExamples) {
            messages.put(JSONObject().put("role", "user").put("content", CloudHttp.wrapTranscript(userEx)))
            messages.put(JSONObject().put("role", "assistant").put("content", asstEx))
        }
        messages.put(JSONObject().put("role", "user").put("content", CloudHttp.wrapTranscript(text)))

        // Claude 4.7 and later reject custom sampling values and think by
        // default, so they get low effort and room for that thinking instead.
        val legacy = acceptsTemperature(model)
        val started = System.currentTimeMillis()
        val raw = CloudHttp.send(
            quirksKey = "anthropic:$model",
            allowTemperatureQuirk = true,
            allowMaxTokensQuirk = false,
            label = "anthropic",
        ) { quirks ->
            val body = JSONObject().apply {
                put("model", model)
                put("system", mode.systemPrompt)
                put("messages", messages)
                if (legacy) {
                    put("max_tokens", CloudHttp.maxOutputTokens(text))
                    if (!quirks.omitTemperature) put("temperature", 0.1)
                } else {
                    put("max_tokens", CloudHttp.maxOutputTokens(text) + 1024)
                    put("output_config", JSONObject().put("effort", "low"))
                }
            }
            Request.Builder()
                .url("https://api.anthropic.com/v1/messages")
                .header("Content-Type", "application/json")
                .header("x-api-key", apiKey)
                .header("anthropic-version", "2023-06-01")
                .post(body.toString().toRequestBody("application/json".toMediaType()))
                .build()
        }

        // { content: [ { type: "thinking", ... }, { type: "text", text: "..." } ] }
        val parsed: JSONArray? = try {
            JSONObject(raw).optJSONArray("content")
        } catch (_: Exception) {
            null
        }
        val content = parsed ?: throw CleanupHttpException("Unexpected response from Anthropic.")
        for (i in 0 until content.length()) {
            val item = content.optJSONObject(i) ?: continue
            if (item.optString("type") == "text") {
                Log.i("NeelSpeak.Cleanup", "anthropic $model ${(System.currentTimeMillis() - started)}ms")
                return item.optString("text")
            }
        }
        throw CleanupHttpException("Anthropic returned no text.")
    }

    companion object {
        private val legacyModelPatterns = listOf(
            Regex("""^claude-(?:instant|2|3)"""),
            Regex("""^claude-(?:haiku|sonnet|opus)-4(?:-[0-6])?(?:-\d{8})?$"""),
        )

        /** True for Claude models that still accept a custom `temperature`
         *  (Claude 3.x and Claude 4.0–4.6, including dated snapshots). */
        fun acceptsTemperature(model: String): Boolean =
            legacyModelPatterns.any { it.containsMatchIn(model) }
    }
}
