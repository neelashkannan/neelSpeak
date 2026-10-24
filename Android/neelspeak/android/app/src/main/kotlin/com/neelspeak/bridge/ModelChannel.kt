package com.neelspeak.bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.neelspeak.app.NeelSpeakApplication
import com.neelspeak.stt.ModelDownloader
import com.neelspeak.stt.ModelStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Method channel `neelspeak/model` + event channel `neelspeak/model/progress`.
 *
 * Method calls:
 *   - isParakeetInstalled() -> Boolean
 *   - isLlmInstalled() -> Boolean
 *   - isDownloading() -> Boolean
 *   - downloadParakeet() -> Unit         (uses the known sherpa-onnx URL)
 *   - downloadLlm(url) -> Unit            (caller supplies HF/local URL)
 *   - cancelDownload() -> Unit
 *   - deleteParakeet() / deleteLlm() -> Unit
 *
 * The download job lives in the companion object so it survives the
 * activity being recreated, and the progress stream replays the last event
 * to a new listener.
 */
class ModelChannel(private val context: Context) {
    private val store = ModelStore(context)

    companion object {
        // Official k2-fsa Parakeet TDT 0.6B INT8 bundle (~190 MB).
        const val PARAKEET_URL =
            "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/" +
                "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2"

        private const val TAG = "NeelSpeak.Model"
        private const val PROGRESS_INTERVAL_MS = 200L

        private val downloader = ModelDownloader()
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        private val main = Handler(Looper.getMainLooper())
        @Volatile private var currentJob: Job? = null
        @Volatile private var sink: EventChannel.EventSink? = null
        @Volatile private var lastProgress: Map<String, Any?>? = null
        @Volatile private var lastProgressAt = 0L
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "neelspeak/model").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isParakeetInstalled" -> result.success(store.isParakeetInstalled())
                    "isLlmInstalled" -> result.success(store.isLlmInstalled())
                    "isDownloading" -> result.success(currentJob?.isActive == true)
                    "deleteParakeet" -> {
                        currentJob?.cancel()
                        coordinator()?.onModelRemoved()
                        store.parakeetDir().deleteRecursively()
                        store.parakeetArchive().delete()
                        result.success(null)
                    }
                    "deleteLlm" -> {
                        store.llmFile().delete()
                        store.llmPartialFile().delete()
                        result.success(null)
                    }
                    "downloadParakeet" -> {
                        if (currentJob?.isActive == true) {
                            // Already running — the listener gets the replayed progress.
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val archive = store.parakeetArchive()
                        val dest = store.parakeetDir()
                        emit(mapOf("phase" to "starting"))
                        currentJob = scope.launch {
                            try {
                                var failed = false
                                downloader.downloadAndExtractTarBz2(PARAKEET_URL, dest, archive).collect {
                                    emit(it)
                                    if (it is ModelDownloader.Progress.Failed) {
                                        failed = true
                                    }
                                }
                                if (!failed) {
                                    if (store.isParakeetInstalled()) {
                                        coordinator()?.onModelInstalled()
                                        emit(mapOf("phase" to "done"))
                                    } else {
                                        dest.deleteRecursively()
                                        emit(
                                            mapOf(
                                                "phase" to "failed",
                                                "message" to "The downloaded Parakeet model was invalid. Please try again.",
                                            )
                                        )
                                    }
                                }
                            } catch (e: CancellationException) {
                                emit(mapOf("phase" to "cancelled"))
                            } catch (t: Throwable) {
                                Log.e(TAG, "model download failed", t)
                                emit(mapOf("phase" to "failed", "message" to (t.message ?: "Download failed")))
                            }
                        }
                        result.success(null)
                    }
                    "downloadLlm" -> {
                        val url: String = call.argument("url") ?: return@setMethodCallHandler result.error("ARG", "url required", null)
                        if (currentJob?.isActive == true) {
                            result.error("BUSY", "Another download is already running", null)
                            return@setMethodCallHandler
                        }
                        emit(mapOf("phase" to "starting"))
                        currentJob = scope.launch {
                            val partial = store.llmPartialFile()
                            try {
                                downloader.download(url, partial).collect {
                                    if (it is ModelDownloader.Progress.Done) {
                                        // Only a complete file ever appears at the final path.
                                        val target = store.llmFile()
                                        target.delete()
                                        if (partial.renameTo(target)) {
                                            emit(it)
                                        } else {
                                            emit(mapOf("phase" to "failed", "message" to "Could not move the model into place"))
                                        }
                                    } else {
                                        emit(it)
                                    }
                                }
                            } catch (e: CancellationException) {
                                emit(mapOf("phase" to "cancelled"))
                            } catch (t: Throwable) {
                                Log.e(TAG, "llm download failed", t)
                                emit(mapOf("phase" to "failed", "message" to (t.message ?: "Download failed")))
                            }
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
                    lastProgress?.let { progress -> main.post { events?.success(progress) } }
                }
                override fun onCancel(arguments: Any?) { sink = null }
            }
        )
    }

    private fun coordinator() =
        (context.applicationContext as? NeelSpeakApplication)?.coordinator

    private fun emit(p: ModelDownloader.Progress) {
        val map: Map<String, Any?> = when (p) {
            is ModelDownloader.Progress.Downloading -> {
                // Byte-level progress arrives every 64 KB; the UI only needs a few updates a second.
                val now = SystemClock.elapsedRealtime()
                val finished = p.totalBytes > 0 && p.bytesRead >= p.totalBytes
                if (!finished && now - lastProgressAt < PROGRESS_INTERVAL_MS) return
                lastProgressAt = now
                mapOf(
                    "phase" to "downloading",
                    "bytesRead" to p.bytesRead,
                    "totalBytes" to p.totalBytes,
                )
            }
            is ModelDownloader.Progress.Extracting -> mapOf("phase" to "extracting", "files" to p.pct)
            ModelDownloader.Progress.Done -> mapOf("phase" to "done")
            is ModelDownloader.Progress.Failed -> mapOf("phase" to "failed", "message" to p.message)
        }
        emit(map)
    }

    private fun emit(map: Map<String, Any?>) {
        lastProgress = map
        val s = sink ?: return
        main.post { s.success(map) }
    }
}
