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

        val body = JSONObject().apply {
            put("model", model)
            put("max_tokens", CloudHttp.maxOutputTokens(text))
            put("temperature", 0.1)
            put("system", mode.systemPrompt)
            put("messages", messages)
        }
        val req = Request.Builder()
            .url("https://api.anthropic.com/v1/messages")
            .header("Content-Type", "application/json")
            .header("x-api-key", apiKey)
            .header("anthropic-version", "2023-06-01")
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val started = System.currentTimeMillis()
        CloudHttp.client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw CleanupHttpException("HTTP ${resp.code}: ${raw.take(200)}")
            }
            val json = JSONObject(raw)
            val content = json.optJSONArray("content")
                ?: throw CleanupHttpException("Unexpected JSON: ${raw.take(200)}")
            for (i in 0 until content.length()) {
                val item = content.optJSONObject(i) ?: continue
                if (item.optString("type") == "text") {
                    Log.i("NeelSpeak.Cleanup", "anthropic $model ${(System.currentTimeMillis() - started)}ms")
                    return item.optString("text")
                }
            }
            throw CleanupHttpException("Unexpected JSON: ${raw.take(200)}")
        }
    }
}
