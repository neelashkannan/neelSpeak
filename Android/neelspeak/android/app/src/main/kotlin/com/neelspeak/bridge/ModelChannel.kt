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
 * Two channels:
 *  - MethodChannel `neelspeak/model` — listModels, downloadModel(id, url),
 *    cancelDownload, deleteModel, isInstalled, isLlmInstalled.
 *  - EventChannel `neelspeak/model/progress` — streams DownloadProgress.
 */
class ModelChannel(private val context: Context) {
    private val store = ModelStore(context)
    private val downloader = ModelDownloader()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var currentJob: Job? = null
    private var sink: EventChannel.EventSink? = null

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
                    "downloadFile" -> {
                        val url: String = call.argument("url") ?: return@setMethodCallHandler result.error("ARG", "url required", null)
                        val relPath: String = call.argument("relPath") ?: return@setMethodCallHandler result.error("ARG", "relPath required", null)
                        val dest = java.io.File(context.filesDir, relPath)
                        currentJob?.cancel()
                        currentJob = scope.launch {
                            downloader.download(url, dest).collect { emit(it) }
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
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
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
            is ModelDownloader.Progress.Extracting -> mapOf("phase" to "extracting", "pct" to p.pct)
            ModelDownloader.Progress.Done -> mapOf("phase" to "done")
            is ModelDownloader.Progress.Failed -> mapOf("phase" to "failed", "message" to p.message)
        }
        android.os.Handler(android.os.Looper.getMainLooper()).post { s.success(map) }
    }

    protected fun finalize() { scope.cancel() }
}
