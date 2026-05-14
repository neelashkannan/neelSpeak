package com.neelspeak.bridge

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel `neelspeak/system` — deep-links the user into system Settings.
 * Used by onboarding for "Enable IME" and "Set as default".
 *   - openImeSettings()
 *   - showImePicker()
 *   - isEnabledIme() -> bool
 *   - isDefaultIme() -> bool
 */
class SystemChannel(private val host: Activity) {
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "neelspeak/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "openImeSettings" -> {
                    host.startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
                    result.success(null)
                }
                "showImePicker" -> {
                    val imm = host.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showInputMethodPicker()
                    result.success(null)
                }
                "isEnabledIme" -> {
                    val imm = host.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    val ours = host.packageName
                    val enabled = imm.enabledInputMethodList.any { it.packageName == ours }
                    result.success(enabled)
                }
                "isDefaultIme" -> {
                    val current = Settings.Secure.getString(
                        host.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD
                    )
                    result.success(current?.startsWith(host.packageName) == true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
