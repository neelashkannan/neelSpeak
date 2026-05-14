package com.neelspeak.bridge

import android.content.Context
import com.neelspeak.stt.ModelDownloader
import com.neelspeak.stt.ModelStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/**
 * Method channel `neelspeak/model` + event channel `neelspeak/model/progress`.
 *
 * Method calls:
 *   - isParakeetInstalled() -> Boolean
 *   - isLlmInstalled() -> Boolean
 *   - downloadParakeet() -> Unit         (uses the known sherpa-onnx URL)
 *   - downloadLlm(url) -> Unit            (caller supplies HF/local URL)
 *   - cancelDownload() -> Unit
 *   - deleteParakeet() / deleteLlm() -> Unit
 */
class ModelChannel(private val context: Context) {
    private val store = ModelStore(context)
    private val downloader = ModelDownloader()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var currentJob: Job? = null
    @Volatile private var sink: EventChannel.EventSink? = null
    @Volatile private var lastProgress: Map<String, Any?>? = null

    companion object {
        // Official k2-fsa Parakeet TDT 0.6B INT8 bundle (~190 MB).
        const val PARAKEET_URL =
            "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/" +
                "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "neelspeak/model").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isParakeetInstalled" -> result.success(store.isParakeetInstalled())
                    "isLlmInstalled" -> result.success(store.isLlmInstalled())
                    "deleteParakeet" -> {
                        store.parakeetDir().deleteRecursively()
                        result.success(null)
                    }
                    "deleteLlm" -> {
                        store.llmFile().delete()
                        result.success(null)
                    }
                    "downloadParakeet" -> {
                        currentJob?.cancel()
                        val tmp = java.io.File(context.cacheDir, "parakeet.tar.bz2")
                        val dest = store.parakeetDir()
                        emit(mapOf("phase" to "starting"))
                        currentJob = scope.launch {
                            downloader.downloadAndExtractTarBz2(PARAKEET_URL, dest, tmp).collect { emit(it) }
                        }
                        result.success(null)
                    }
                    "downloadLlm" -> {
                        val url: String = call.argument("url") ?: return@setMethodCallHandler result.error("ARG", "url required", null)
                        currentJob?.cancel()
                        emit(mapOf("phase" to "starting"))
                        currentJob = scope.launch {
                            downloader.download(url, store.llmFile()).collect { emit(it) }
                        }
                        result.success(null)
                    }
                    "cancelDownload" -> {
                        currentJob?.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                result.error("NATIVE", t.message, null)
            }
        }

        EventChannel(messenger, "neelspeak/model/progress").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    lastProgress?.let { progress ->
                        android.os.Handler(android.os.Looper.getMainLooper()).post { events?.success(progress) }
                    }
                }
                override fun onCancel(arguments: Any?) { sink = null }
            }
        )
    }

    private fun emit(p: ModelDownloader.Progress) {
        val s = sink ?: return
        val map: Map<String, Any?> = when (p) {
            is ModelDownloader.Progress.Downloading -> mapOf(
                "phase" to "downloading",
                "bytesRead" to p.bytesRead,
                "totalBytes" to p.totalBytes,
            )
            is ModelDownloader.Progress.Extracting -> mapOf("phase" to "extracting", "files" to p.pct)
            ModelDownloader.Progress.Done -> mapOf("phase" to "done")
            is ModelDownloader.Progress.Failed -> mapOf("phase" to "failed", "message" to p.message)
        }
        emit(map)
    }

    private fun emit(map: Map<String, Any?>) {
        lastProgress = map
        val s = sink ?: return
        android.os.Handler(android.os.Looper.getMainLooper()).post { s.success(map) }
    }

    protected fun finalize() { scope.cancel() }
}
