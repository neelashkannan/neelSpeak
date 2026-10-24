package com.neelspeak.cleanup

import okhttp3.Request
import org.json.JSONObject

/**
 * GitHub Copilot chat-completions client. Mirrors
 * `CloudCleanupService.cleanWithCopilot` from CloudCleanupService.swift. The
 * caller (the coordinator) is responsible for refreshing the session token via
 * [CopilotAuthService.fetchSessionToken] when it expires.
 */
class CopilotCleanupClient {
    fun clean(text: String, mode: CleanupMode, sessionToken: String, model: String): String =
        OpenAiCleanupClient.chatCompletion(
            url = "https://api.githubcopilot.com/chat/completions",
            quirksKey = "api.githubcopilot.com:$model",
            headers = EDITOR_HEADERS + mapOf(
                "Authorization" to "Bearer $sessionToken",
                "Openai-Intent" to "2025-01-01",
            ),
            model = model,
            text = text,
            mode = mode,
            label = "copilot",
        )

    /** GET /models on the Copilot endpoint. Returns chat-capable, picker-enabled model IDs. */
    fun fetchModels(sessionToken: String): List<String> {
        val req = Request.Builder()
            .url("https://api.githubcopilot.com/models")
            .apply { EDITOR_HEADERS.forEach { (k, v) -> header(k, v) } }
            .header("Authorization", "Bearer $sessionToken")
            .header("Accept", "application/json")
            .get()
            .build()
        CloudHttp.client.newCall(req).execute().use { resp ->
            val raw = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw CleanupHttpException(CloudHttp.describeHttpError(resp.code, raw))
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

    companion object {
        /** Headers Copilot's gateway expects from an editor integration —
         *  without them it refuses requests. */
        private val EDITOR_HEADERS = mapOf(
            "Editor-Version" to "vscode/1.95.0",
            "Editor-Plugin-Version" to "copilot-chat/0.22.0",
            "User-Agent" to "GithubCopilot/1.155.0",
        )
    }
}
