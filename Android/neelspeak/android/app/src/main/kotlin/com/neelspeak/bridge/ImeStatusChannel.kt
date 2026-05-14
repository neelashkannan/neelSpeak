package com.neelspeak.bridge

import android.app.Activity
import com.neelspeak.app.NeelSpeakApplication
import com.neelspeak.coordinator.DictationState
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

/**
 * EventChannel `neelspeak/ime/status` — streams the coordinator's
 * DictationState so the settings UI can show "Listening…" indicators or a
 * model-warming spinner.
 */
class ImeStatusChannel(private val host: Activity) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var job: Job? = null

    fun register(messenger: BinaryMessenger) {
        EventChannel(messenger, "neelspeak/ime/status").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    job?.cancel()
                    val app = host.applicationContext as NeelSpeakApplication
                    job = scope.launch {
                        app.coordinator.state.collectLatest { state ->
                            val payload: Map<String, Any?> = mapOf(
                                "state" to state.label,
                                "message" to (state as? DictationState.Error)?.message,
                                "progress" to (state as? DictationState.DownloadingModel)?.progress,
                            )
                            events?.success(payload)
                        }
                    }
                }
                override fun onCancel(arguments: Any?) {
                    job?.cancel()
                    job = null
                }
            }
        )
    }

    protected fun finalize() { scope.cancel() }
}
