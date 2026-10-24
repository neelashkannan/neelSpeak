package com.neelspeak.bridge

import android.content.Context
import com.neelspeak.prefs.SecureStore
import com.neelspeak.prefs.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel `neelspeak/settings`:
 *  - getAll() → Map of plain SharedPreferences entries
 *  - set(key, value)
 *  - hasSecure(key) → Boolean      (EncryptedSharedPreferences; secret values
 *    are write-only from Dart and never sent back across the channel)
 *  - setSecure(key, value)
 *  - clearSecure(key)
 */
class SettingsChannel(context: Context) {
    private val settings = Settings(context)
    private val secrets = SecureStore(context)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "neelspeak/settings").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getAll" -> result.success(settings.snapshot())
                    "set" -> {
                        val key: String = call.argument("key") ?: return@setMethodCallHandler result.error("ARG", "key required", null)
                        val value: Any? = call.argument("value")
                        settings.set(key, value)
                        result.success(null)
                    }
                    "hasSecure" -> {
                        val key: String = call.argument("key") ?: return@setMethodCallHandler result.error("ARG", "key required", null)
                        result.success(secrets.has(key))
                    }
                    "setSecure" -> {
                        val key: String = call.argument("key") ?: return@setMethodCallHandler result.error("ARG", "key required", null)
                        val value: String = call.argument("value") ?: return@setMethodCallHandler result.error("ARG", "value required", null)
                        secrets.set(key, value)
                        result.success(null)
                    }
                    "clearSecure" -> {
                        val key: String = call.argument("key") ?: return@setMethodCallHandler result.error("ARG", "key required", null)
                        secrets.clear(key)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                // Never echo the call arguments: they may carry a secret value.
                result.error("NATIVE", t.javaClass.simpleName, null)
            }
        }
    }
}
