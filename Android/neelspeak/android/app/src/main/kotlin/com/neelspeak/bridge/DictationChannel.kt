package com.neelspeak.bridge

import com.neelspeak.app.NeelSpeakApplication
import com.neelspeak.coordinator.DictationState
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.time.Duration.Companion.seconds

/**
 * Method channel `neelspeak/dictation`. Lets the settings/onboarding UI drive
 * the shared DictationCoordinator so the user can test the STT pipeline
 * without enabling the keyboard. Mirrors the begin/end gesture from the IME.
 *
 *  - start() — begin recording.
 *  - stopAndAwait() — stop, run STT + cleanup, return the resulting text (or
 *    "" on timeout / error). Awaits up to 30 s for the transcript.
 *  - warm() — preload the local recognizer so first transcription is faster.
 *  - state() — current coordinator state label.
 */
class DictationChannel(application: NeelSpeakApplication) {
    private val coord = application.coordinator
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "neelspeak/dictation").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    coord.beginDictation()
                    result.success(coord.state.value.label)
                }
                "warm" -> {
                    scope.launch(Dispatchers.IO) {
                        val ok = coord.warmStt()
                        withContext(Dispatchers.Main) { result.success(ok) }
                    }
                }
                "stopAndAwait" -> {
                    scope.launch {
                        coord.endDictation()
                        val text = withTimeoutOrNull(30.seconds) {
                            coord.transcripts.first()
                        } ?: ""
                        withContext(Dispatchers.Main) { result.success(text) }
                    }
                }
                "state" -> result.success(coord.state.value.label)
                else -> result.notImplemented()
            }
        }
    }

    protected fun finalize() { scope.cancel() }
}
