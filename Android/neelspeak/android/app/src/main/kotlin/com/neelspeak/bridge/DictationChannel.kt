package com.neelspeak.bridge

import com.neelspeak.app.NeelSpeakApplication
import com.neelspeak.coordinator.DictationCoordinator
import com.neelspeak.coordinator.DictationState
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.time.Duration.Companion.seconds

/**
 * Method channel `neelspeak/dictation`. Lets the settings/onboarding UI drive
 * the shared DictationCoordinator so the user can test the STT pipeline
 * without enabling the keyboard. Mirrors the begin/end gesture from the IME.
 * Results of these dictations are never typed by the keyboard.
 *
 *  - start() — begin recording; returns the state label afterwards, or
 *    "busy" when the keyboard is already dictating.
 *  - stopAndAwait() — stop, run STT + cleanup, return the resulting text (or
 *    "" when nothing was heard, on error, or after 60 s).
 *  - cancel() — discard the current test dictation.
 *  - warm() — preload the local recognizer so first transcription is faster.
 *  - state() — current coordinator state label.
 *  - errorMessage() — message of the current error state, if any.
 */
class DictationChannel(application: NeelSpeakApplication) {
    private val coord = application.coordinator
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "neelspeak/dictation").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val s = coord.state.value
                    if (s is DictationState.Recording || s is DictationState.Transcribing ||
                        s is DictationState.Cleaning
                    ) {
                        // The keyboard is mid-dictation; don't take it over.
                        result.success("busy")
                        return@setMethodCallHandler
                    }
                    coord.beginDictation(DictationCoordinator.Origin.App)
                    result.success(coord.state.value.label)
                }
                "warm" -> {
                    scope.launch(Dispatchers.IO) {
                        val ok = coord.warmStt()
                        withContext(Dispatchers.Main) { result.success(ok) }
                    }
                }
                "stopAndAwait" -> {
                    if (coord.state.value !is DictationState.Recording) {
                        result.success("")
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        // Subscribe before ending so a fast result can't slip past.
                        val pending = async(start = CoroutineStart.UNDISPATCHED) {
                            withTimeoutOrNull(60.seconds) {
                                coord.results.first { it.origin == DictationCoordinator.Origin.App }
                            }
                        }
                        coord.endDictation()
                        result.success(pending.await()?.text ?: "")
                    }
                }
                "cancel" -> {
                    coord.cancelDictation()
                    result.success(null)
                }
                "state" -> result.success(coord.state.value.label)
                "errorMessage" -> result.success((coord.state.value as? DictationState.Error)?.message)
                else -> result.notImplemented()
            }
        }
    }
}
