package com.neelspeak.prefs

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * AES256-GCM EncryptedSharedPreferences wrapper for API keys + OAuth tokens.
 * File name [SettingsKeys.PREFS_SECRETS]. Accessible to both the IME service
 * and the Flutter MainActivity since they live in the same package.
 */
class SecureStore(context: Context) {
    private val prefs: SharedPreferences = run {
        val master = MasterKey.Builder(context.applicationContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context.applicationContext,
            SettingsKeys.PREFS_SECRETS,
            master,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun get(key: String): String? = prefs.getString(key, null)
    fun set(key: String, value: String) = prefs.edit().putString(key, value).apply()
    fun clear(key: String) = prefs.edit().remove(key).apply()
}
