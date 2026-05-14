package com.neelspeak.bridge

import android.content.Context
import com.neelspeak.cleanup.CopilotAuthService
import com.neelspeak.prefs.SecureStore
import com.neelspeak.prefs.SettingsKeys
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * MethodChannel `neelspeak/copilot`:
 *  - requestDeviceCode() -> Map
 *  - pollForOAuthToken(deviceCode, pollIntervalSeconds, expiresAtMillis) -> stores
 *    OAuth token in EncryptedSharedPreferences on success and returns null.
 *  - signOut() -> clears OAuth token
 */
class CopilotAuthChannel(context: Context) {
    private val secrets = SecureStore(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "neelspeak/copilot").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDeviceCode" -> scope.launch {
                    try {
                        val code = CopilotAuthService.requestDeviceCode()
                        withContext(Dispatchers.Main) {
                            result.success(mapOf(
                                "deviceCode" to code.deviceCode,
                                "userCode" to code.userCode,
                                "verificationUrl" to code.verificationURL,
                                "verificationUrlComplete" to code.verificationURLComplete,
                                "intervalSeconds" to code.pollIntervalSeconds,
                                "expiresAtMillis" to code.expiresAtMillis,
                            ))
                        }
                    } catch (t: Throwable) {
                        withContext(Dispatchers.Main) { result.error("AUTH", t.message, null) }
                    }
                }
                "pollForOAuthToken" -> scope.launch {
                    val deviceCode: String? = call.argument("deviceCode")
                    if (deviceCode == null) {
                        withContext(Dispatchers.Main) { result.error("ARG", "deviceCode required", null) }
                        return@launch
                    }
                    val interval: Int = call.argument("intervalSeconds") ?: 5
                    val expiresAt: Long = call.argument("expiresAtMillis") ?: (System.currentTimeMillis() + 5 * 60 * 1000L)
                    try {
                        val dc = CopilotAuthService.DeviceCode(
                            deviceCode = deviceCode,
                            userCode = "",
                            verificationURL = "",
                            verificationURLComplete = null,
                            pollIntervalSeconds = interval,
                            expiresAtMillis = expiresAt,
                        )
                        val token = CopilotAuthService.pollForOAuthToken(dc)
                        secrets.set(SettingsKeys.CLOUD_COPILOT_OAUTH, token)
                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (t: Throwable) {
                        withContext(Dispatchers.Main) { result.error("AUTH", t.message, null) }
                    }
                }
                "signOut" -> {
                    secrets.clear(SettingsKeys.CLOUD_COPILOT_OAUTH)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
