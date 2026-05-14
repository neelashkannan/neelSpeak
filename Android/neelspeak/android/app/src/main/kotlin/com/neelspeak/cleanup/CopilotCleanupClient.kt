package com.neelspeak.cleanup

import android.util.Log
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

/**
 * GitHub Copilot chat-completions client. Mirrors
 * `CloudCleanupService.cleanWithCopilot` from CloudCleanupService.swift. The
 * caller (the coordinator) is responsible for refreshing the session token via
 * [CopilotAuthService.fetchSessionToken] when it expires.
 */
class CopilotCleanupClient {
    fun clean(text: String, mode: CleanupMode, sessionToken: String, model: String): String {
        val messages = JSONArray()
        messages.put(JSONObject().put("role", "system").put("content", mode.systemPrompt))
        for ((userEx, asstEx) in mode.fewShotExamples) {
            messages.put(JSONObject().put("role", "user").put("content", CloudHttp.wrapTranscript(userEx)))
            messages.put(JSONObject().put("role", "assistant").put("content", asstEx))
        }
        messages.put(JSONObject().put("role", "user").put("content", CloudHttp.wrapTranscript(text)))

        val body = JSONObject().apply {
            put("model", model)
            put("temperature", 0.1)
            put("max_tokens", CloudHttp.maxOutputTokens(text))
            put("messages", messages)
        }

        val req = Request.Builder()
            .url("https://api.githubcopilot.com/chat/completions")
            .header("Content-Type", "application/json")
            .header("Authorization", "Bearer $sessionToken")
            .header("Editor-Version", "vscode/1.95.0")
            .header("Editor-Plugin-Version", "copilot-chat/0.22.0")
            .header("User-Agent", "GithubCopilot/1.155.0")
            .header("Openai-Intent", "2025-01-01")
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val started = System.currentTimeMillis()
        CloudHttp.client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw CleanupHttpException("HTTP ${resp.code}: ${raw.take(200)}")
            }
            val json = JSONObject(raw)
            val message = json.optJSONArray("choices")?.optJSONObject(0)?.optJSONObject("message")
                ?: throw CleanupHttpException("Unexpected JSON: ${raw.take(200)}")
            Log.i("NeelSpeak.Cleanup", "copilot $model ${(System.currentTimeMillis() - started)}ms")
            return message.optString("content")
        }
    }

    /** GET /models on the Copilot endpoint. Returns chat-capable, picker-enabled model IDs. */
    fun fetchModels(sessionToken: String): List<String> {
        val req = Request.Builder()
            .url("https://api.githubcopilot.com/models")
            .header("Authorization", "Bearer $sessionToken")
            .header("Editor-Version", "vscode/1.95.0")
            .header("Editor-Plugin-Version", "copilot-chat/0.22.0")
            .header("User-Agent", "GithubCopilot/1.155.0")
            .header("Accept", "application/json")
            .get()
            .build()
        CloudHttp.client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw CleanupHttpException("HTTP ${resp.code}: ${raw.take(200)}")
            val data = JSONObject(raw).optJSONArray("data") ?: return emptyList()
            val ids = mutableListOf<String>()
            for (i in 0 until data.length()) {
                val item = data.optJSONObject(i) ?: continue
                val id = item.optString("id").takeIf { it.isNotEmpty() } ?: continue
                val caps = item.optJSONObject("capabilities")
                if (caps != null && caps.optString("type", "chat") != "chat") continue
                if (item.has("model_picker_enabled") && !item.optBoolean("model_picker_enabled")) continue
                ids.add(id)
            }
            return ids.sorted()
        }
    }
}
