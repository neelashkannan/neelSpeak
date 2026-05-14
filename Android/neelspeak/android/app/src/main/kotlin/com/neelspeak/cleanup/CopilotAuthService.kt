package com.neelspeak.cleanup

import android.util.Log
import kotlinx.coroutines.delay
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * GitHub Copilot OAuth device flow. Port of
 * Sources/VoiceTyper/Pipeline/CopilotAuthService.swift.
 *
 * Step 1: requestDeviceCode() → user code + verification URL. User opens the URL,
 *         signs in, and enters the user code.
 * Step 2: pollForOAuthToken(code) → poll until authorized; returns ghu_... token.
 * Step 3: fetchSessionToken(token) → exchange OAuth token for a short-lived
 *         (~30 min) Copilot session token used against api.githubcopilot.com.
 */
object CopilotAuthService {
    private const val TAG = "CopilotAuth"

    /** Well-known GitHub OAuth client ID used by the official Copilot CLI and
     *  editor extensions. Not a secret. */
    const val CLIENT_ID = "Iv1.b507a08c87ecfe98"

    private val http = OkHttpClient.Builder()
        .callTimeout(15, TimeUnit.SECONDS)
        .build()

    data class DeviceCode(
        val deviceCode: String,
        val userCode: String,
        val verificationURL: String,
        val verificationURLComplete: String?,
        val pollIntervalSeconds: Int,
        val expiresAtMillis: Long,
    )

    data class SessionToken(
        val token: String,
        val expiresAtMillis: Long,
    )

    class AuthException(message: String, val kind: Kind) : Exception(message) {
        enum class Kind { Http, Decoding, AuthorizationPending, SlowDown, Expired, Denied, Other }
    }

    suspend fun requestDeviceCode(): DeviceCode {
        val form = "client_id=$CLIENT_ID&scope=read%3Auser"
            .toRequestBody("application/x-www-form-urlencoded".toMediaType())
        val req = Request.Builder()
            .url("https://github.com/login/device/code")
            .header("Accept", "application/json")
            .post(form)
            .build()

        http.newCall(req).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw AuthException("HTTP ${resp.code}: ${body.take(200)}", AuthException.Kind.Http)
            }
            val json = JSONObject(body)
            return DeviceCode(
                deviceCode = json.getString("device_code"),
                userCode = json.getString("user_code"),
                verificationURL = json.getString("verification_uri"),
                verificationURLComplete = json.optString("verification_uri_complete")
                    .takeIf { it.isNotEmpty() },
                pollIntervalSeconds = json.getInt("interval"),
                expiresAtMillis = System.currentTimeMillis() + json.getInt("expires_in") * 1000L,
            )
        }
    }

    suspend fun pollForOAuthToken(code: DeviceCode): String {
        var interval = code.pollIntervalSeconds.toLong()
        while (System.currentTimeMillis() < code.expiresAtMillis) {
            delay(interval * 1000L)
            try {
                pollOnce(code.deviceCode)?.let { return it }
            } catch (e: AuthException) {
                when (e.kind) {
                    AuthException.Kind.SlowDown -> interval += 5
                    AuthException.Kind.AuthorizationPending -> { /* keep polling */ }
                    else -> throw e
                }
            }
        }
        throw AuthException("Device code expired — start over", AuthException.Kind.Expired)
    }

    private fun pollOnce(deviceCode: String): String? {
        val form = "client_id=$CLIENT_ID&device_code=$deviceCode&grant_type=urn:ietf:params:oauth:grant-type:device_code"
            .toRequestBody("application/x-www-form-urlencoded".toMediaType())
        val req = Request.Builder()
            .url("https://github.com/login/oauth/access_token")
            .header("Accept", "application/json")
            .post(form)
            .build()
        http.newCall(req).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw AuthException("HTTP ${resp.code}: ${body.take(200)}", AuthException.Kind.Http)
            }
            val json = JSONObject(body)
            json.optString("access_token").takeIf { it.isNotEmpty() }?.let { return it }
            when (val err = json.optString("error")) {
                "authorization_pending" -> throw AuthException(err, AuthException.Kind.AuthorizationPending)
                "slow_down" -> throw AuthException(err, AuthException.Kind.SlowDown)
                "expired_token" -> throw AuthException(err, AuthException.Kind.Expired)
                "access_denied" -> throw AuthException(err, AuthException.Kind.Denied)
                "" -> return null
                else -> throw AuthException(err, AuthException.Kind.Other)
            }
        }
    }

    fun fetchSessionToken(oauthToken: String): SessionToken {
        val req = Request.Builder()
            .url("https://api.github.com/copilot_internal/v2/token")
            .header("Authorization", "Bearer $oauthToken")
            .header("Accept", "application/json")
            .header("User-Agent", "GithubCopilot/1.155.0")
            .header("Editor-Version", "vscode/1.95.0")
            .header("Editor-Plugin-Version", "copilot/1.155.0")
            .get()
            .build()
        http.newCall(req).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw AuthException("HTTP ${resp.code}: ${body.take(200)}", AuthException.Kind.Http)
            }
            val json = JSONObject(body)
            val token = json.getString("token")
            val expiresAt = json.getLong("expires_at") * 1000L
            Log.i(TAG, "Fetched Copilot session token (expires_at=$expiresAt)")
            return SessionToken(token, expiresAt)
        }
    }
}
