package com.neelspeak.cleanup

import android.util.Log
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
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
        val url = "$trimmed/chat/completions".toHttpUrlOrNull()
            ?: throw CleanupHttpException("Bad base URL: $baseURL")
        return chatCompletion(
            url = url.toString(),
            quirksKey = "${url.host}:$model",
            headers = mapOf("Authorization" to "Bearer $apiKey"),
            model = model,
            text = text,
            mode = mode,
            label = "openai-compat",
        )
    }

    companion object {
        /** Chat-completions call shared by the OpenAI-compatible and Copilot engines. */
        internal fun chatCompletion(
            url: String,
            quirksKey: String,
            headers: Map<String, String>,
            model: String,
            text: String,
            mode: CleanupMode,
            label: String,
        ): String {
            val started = System.currentTimeMillis()
            val raw = CloudHttp.send(
                quirksKey = quirksKey,
                allowTemperatureQuirk = true,
                allowMaxTokensQuirk = true,
                label = label,
            ) { quirks ->
                val body = JSONObject().apply {
                    put("model", model)
                    put("messages", buildMessages(text, mode))
                    if (!quirks.omitTemperature) put("temperature", 0.1)
                    val tokenField = if (quirks.useMaxCompletionTokens) "max_completion_tokens" else "max_tokens"
                    put(tokenField, CloudHttp.maxOutputTokens(text))
                }
                Request.Builder()
                    .url(url)
                    .header("Content-Type", "application/json")
                    .apply { headers.forEach { (k, v) -> header(k, v) } }
                    .post(body.toString().toRequestBody("application/json".toMediaType()))
                    .build()
            }

            // { choices: [ { message: { content: "..." } } ] }
            val message = try {
                JSONObject(raw).optJSONArray("choices")?.optJSONObject(0)?.optJSONObject("message")
            } catch (_: Exception) {
                null
            }
            val content = message?.optString("content")
                ?: throw CleanupHttpException("Unexpected response from the provider.")
            Log.i("NeelSpeak.Cleanup", "$label $model ${(System.currentTimeMillis() - started)}ms")
            return content
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
}
