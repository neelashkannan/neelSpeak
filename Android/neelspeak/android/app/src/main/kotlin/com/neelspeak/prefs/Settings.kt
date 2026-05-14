package com.neelspeak.prefs

import android.content.Context
import android.content.SharedPreferences

/**
 * Wrapper around the plain SharedPreferences used by the IME and Flutter
 * settings UI. Same package = same UID, so both processes write the same file.
 */
class Settings(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(SettingsKeys.PREFS_PLAIN, Context.MODE_PRIVATE)

    fun getString(key: String, default: String = ""): String = prefs.getString(key, default) ?: default
    fun getBool(key: String, default: Boolean = false): Boolean = prefs.getBoolean(key, default)

    fun set(key: String, value: Any?) {
        val edit = prefs.edit()
        when (value) {
            null -> edit.remove(key)
            is String -> edit.putString(key, value)
            is Boolean -> edit.putBoolean(key, value)
            is Int -> edit.putInt(key, value)
            is Long -> edit.putLong(key, value)
            is Float -> edit.putFloat(key, value)
            else -> edit.putString(key, value.toString())
        }
        edit.apply()
    }

    fun snapshot(): Map<String, Any?> = prefs.all
    fun registerListener(l: SharedPreferences.OnSharedPreferenceChangeListener) =
        prefs.registerOnSharedPreferenceChangeListener(l)
    fun unregisterListener(l: SharedPreferences.OnSharedPreferenceChangeListener) =
        prefs.unregisterOnSharedPreferenceChangeListener(l)
}
