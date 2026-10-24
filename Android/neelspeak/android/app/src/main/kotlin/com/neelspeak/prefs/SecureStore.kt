package com.neelspeak.prefs

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * AES256-GCM EncryptedSharedPreferences wrapper for API keys + OAuth tokens.
 * File name [SettingsKeys.PREFS_SECRETS]. Accessible to both the IME service
 * and the Flutter MainActivity since they live in the same package.
 *
 * The file is excluded from backup (see res/xml/data_extraction_rules.xml):
 * its master key lives in this device's Keystore, so a restored copy could
 * never be decrypted. If it still can't be opened (Keystore reset, corrupt
 * file), it is wiped and recreated — the user re-enters their keys rather
 * than the keyboard crashing.
 */
class SecureStore(context: Context) {
    private val prefs: SharedPreferences = shared(context.applicationContext)

    fun get(key: String): String? = prefs.getString(key, null)
    fun has(key: String): Boolean = !prefs.getString(key, null).isNullOrEmpty()
    fun set(key: String, value: String) = prefs.edit().putString(key, value).apply()
    fun clear(key: String) = prefs.edit().remove(key).apply()

    companion object {
        @Volatile private var instance: SharedPreferences? = null

        private fun shared(context: Context): SharedPreferences =
            instance ?: synchronized(this) {
                instance ?: open(context).also { instance = it }
            }

        private fun open(context: Context): SharedPreferences =
            try {
                create(context)
            } catch (t: Throwable) {
                Log.w("NeelSpeak.Secrets", "secret store unreadable (${t.javaClass.simpleName}); resetting it")
                context.deleteSharedPreferences(SettingsKeys.PREFS_SECRETS)
                create(context)
            }

        private fun create(context: Context): SharedPreferences {
            val master = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            return EncryptedSharedPreferences.create(
                context,
                SettingsKeys.PREFS_SECRETS,
                master,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )
        }
    }
}
