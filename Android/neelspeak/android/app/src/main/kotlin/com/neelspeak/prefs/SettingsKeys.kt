package com.neelspeak.prefs

/**
 * SharedPreferences keys. Plain-string keys mirror the macOS UserDefaults
 * keys from CLAUDE.md verbatim where possible so docs/screenshots stay
 * portable across platforms.
 *
 * Secret keys live in [SecureStore] (EncryptedSharedPreferences).
 */
object SettingsKeys {
    // Plain settings
    const val SELECTED_MODEL_ID = "selectedModelID"
    const val SETUP_COMPLETE = "setupComplete"
    const val CLEANUP_MODE = "cleanupMode"
    const val CLEANUP_ENGINE = "cleanupEngine"
    const val CLOUD_OPENAI_BASE_URL = "cloud.openai.baseURL"
    const val CLOUD_OPENAI_MODEL = "cloud.openai.model"
    const val CLOUD_ANTHROPIC_MODEL = "cloud.anthropic.model"
    const val CLOUD_COPILOT_MODEL = "cloud.copilot.model"
    const val ON_DEVICE_LLM_ID = "onDevice.llm.id"
    const val THEME_ID = "theme.id"

    // Secrets (EncryptedSharedPreferences)
    const val CLOUD_OPENAI_KEY = "cloud.openai.apiKey"
    const val CLOUD_ANTHROPIC_KEY = "cloud.anthropic.apiKey"
    const val CLOUD_COPILOT_OAUTH = "cloud.copilot.oauthToken"
    const val CLOUD_HF_TOKEN = "cloud.huggingface.token"

    const val PREFS_PLAIN = "neelspeak_settings"
    const val PREFS_SECRETS = "neelspeak_secrets"
}
