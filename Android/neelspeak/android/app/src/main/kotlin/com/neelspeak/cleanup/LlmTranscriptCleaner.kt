package com.neelspeak.cleanup

import android.content.Context
import com.neelspeak.prefs.SecureStore
import com.neelspeak.prefs.Settings
import com.neelspeak.prefs.SettingsKeys
import com.neelspeak.stt.ModelStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Dispatches a transcript to the configured cleanup engine. Mirrors
 * LLMTranscriptCleaner.swift but the engine selection lives in
 * SharedPreferences and is re-read on each call so the IME picks up settings
 * changes from the Flutter app instantly.
 */
class LlmTranscriptCleaner(private val context: Context) {
    private val settings = Settings(context)
    private val secrets = SecureStore(context)
    private val openAi = OpenAiCleanupClient()
    private val anthropic = AnthropicCleanupClient()
    private val copilot = CopilotCleanupClient()
    private val onDevice by lazy { OnDeviceLlmClient(context, ModelStore(context)) }

    private var copilotSession: CopilotAuthService.SessionToken? = null

    suspend fun clean(text: String, mode: CleanupMode): String {
        if (mode == CleanupMode.Off || text.isBlank()) return text
        val engine = CleanupEngine.fromRaw(settings.getString(SettingsKeys.CLEANUP_ENGINE))
        return withContext(Dispatchers.IO) {
            when (engine) {
                CleanupEngine.OpenAICompatible -> openAi.clean(
                    text,
                    mode,
                    settings.getString(SettingsKeys.CLOUD_OPENAI_BASE_URL).ifEmpty { "https://api.openai.com/v1" },
                    secrets.get(SettingsKeys.CLOUD_OPENAI_KEY).orEmpty(),
                    settings.getString(SettingsKeys.CLOUD_OPENAI_MODEL).ifEmpty { "gpt-4o-mini" },
                )
                CleanupEngine.Anthropic -> anthropic.clean(
                    text,
                    mode,
                    secrets.get(SettingsKeys.CLOUD_ANTHROPIC_KEY).orEmpty(),
                    settings.getString(SettingsKeys.CLOUD_ANTHROPIC_MODEL).ifEmpty { "claude-haiku-4-5" },
                )
                CleanupEngine.GithubCopilot -> {
                    val session = ensureCopilotSession()
                    copilot.clean(
                        text,
                        mode,
                        session.token,
                        settings.getString(SettingsKeys.CLOUD_COPILOT_MODEL).ifEmpty { "gpt-4o-mini" },
                    )
                }
                CleanupEngine.OnDeviceLlm -> onDevice.clean(text, mode)
            }.let { cleaned -> sanitize(cleaned) }
        }
    }

    private fun ensureCopilotSession(): CopilotAuthService.SessionToken {
        val cached = copilotSession
        if (cached != null && System.currentTimeMillis() < cached.expiresAtMillis - 60_000L) {
            return cached
        }
        val oauth = secrets.get(SettingsKeys.CLOUD_COPILOT_OAUTH)
            ?: throw CleanupHttpException("Sign in to GitHub Copilot in NeelSpeak settings.")
        val fresh = CopilotAuthService.fetchSessionToken(oauth)
        copilotSession = fresh
        return fresh
    }

    /** Strip role markers, leading "Sure, here's:" boilerplate, and outer
     *  quotes that some models add despite the prompt. */
    private fun sanitize(raw: String): String {
        var out = raw.trim()
        out = out.removePrefix("```").removeSuffix("```").trim()
        // Strip a leading "Here:" / "Sure," style prefix terminated by a colon on
        // the first line.
        out = out.replaceFirst(Regex("^(?i)(sure|here(?: is| you go| ya go)?|cleaned)[:,]?\\s*\\n+"), "")
        out = out.removeSurrounding("\"").removeSurrounding("'")
        return out.trim()
    }

    fun copilotFetchModels(): List<String> {
        val session = ensureCopilotSession()
        return copilot.fetchModels(session.token)
    }
}
