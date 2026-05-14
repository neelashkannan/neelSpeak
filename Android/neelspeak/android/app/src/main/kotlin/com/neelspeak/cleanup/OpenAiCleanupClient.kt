package com.neelspeak.cleanup

import android.util.Log
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

/**
 * OpenAI-compatible chat-completions client. Works against OpenAI direct, GitHub
 * Models, OpenRouter, Groq, Ollama, OpenCode. Mirrors
 * `CloudCleanupService.cleanWithOpenAICompatible` in CloudCleanupService.swift.
 */
class OpenAiCleanupClient {
    fun clean(text: String, mode: CleanupMode, baseURL: String, apiKey: String, model: String): String {
        if (apiKey.isEmpty()) throw CleanupHttpException(
            "API key not configured. Open NeelSpeak settings and paste your key."
        )

        val trimmed = baseURL.trim().trimEnd('/')
        val url = "$trimmed/chat/completions"

        val body = JSONObject().apply {
            put("model", model)
            put("temperature", 0.1)
            put("max_tokens", CloudHttp.maxOutputTokens(text))
            put("messages", buildMessages(text, mode))
        }
        val req = Request.Builder()
            .url(url)
            .header("Content-Type", "application/json")
            .header("Authorization", "Bearer $apiKey")
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val started = System.currentTimeMillis()
        CloudHttp.client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw CleanupHttpException("HTTP ${resp.code}: ${raw.take(200)}")
            }
            val json = JSONObject(raw)
            val choices = json.optJSONArray("choices")
                ?: throw CleanupHttpException("Unexpected JSON: ${raw.take(200)}")
            val message = choices.optJSONObject(0)?.optJSONObject("message")
                ?: throw CleanupHttpException("Unexpected JSON: ${raw.take(200)}")
            val content = message.optString("content")
            Log.i("NeelSpeak.Cleanup", "openai-compat $model ${(System.currentTimeMillis() - started)}ms")
            return content
        }
    }

    private fun buildMessages(text: String, mode: CleanupMode): JSONArray {
        val arr = JSONArray()
        arr.put(JSONObject().put("role", "system").put("content", mode.systemPrompt))
        for ((userEx, asstEx) in mode.fewShotExamples) {
            arr.put(JSONObject().put("role", "user").put("content", CloudHttp.wrapTranscript(userEx)))
            arr.put(JSONObject().put("role", "assistant").put("content", asstEx))
        }
        arr.put(JSONObject().put("role", "user").put("content", CloudHttp.wrapTranscript(text)))
        return arr
    }
}
