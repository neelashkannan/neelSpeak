package com.neelspeak.bridge

import android.content.Context
import com.neelspeak.cleanup.CleanupMode
import com.neelspeak.cleanup.LlmTranscriptCleaner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * MethodChannel `neelspeak/cleanup` — settings → "Test cleanup" page calls
 * this with a canned transcript to measure roundtrip latency for the
 * currently configured engine.
 */
class CleanupChannel(context: Context) {
    private val cleaner = LlmTranscriptCleaner(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "neelspeak/cleanup").setMethodCallHandler { call, result ->
            when (call.method) {
                "test" -> scope.launch {
                    val text: String = call.argument("text") ?: run {
                        withContext(Dispatchers.Main) { result.error("ARG", "text required", null) }
                        return@launch
                    }
                    val mode = CleanupMode.fromRaw(call.argument("mode"))
                    val started = System.currentTimeMillis()
                    try {
                        val out = cleaner.clean(text, mode)
                        withContext(Dispatchers.Main) {
                            result.success(mapOf(
                                "result" to out,
                                "latencyMs" to (System.currentTimeMillis() - started),
                            ))
                        }
                    } catch (t: Throwable) {
                        withContext(Dispatchers.Main) { result.error("CLEANUP", t.message, null) }
                    }
                }
                "fetchCopilotModels" -> scope.launch {
                    try {
                        val models = cleaner.copilotFetchModels()
                        withContext(Dispatchers.Main) { result.success(models) }
                    } catch (t: Throwable) {
                        withContext(Dispatchers.Main) { result.error("CLEANUP", t.message, null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
