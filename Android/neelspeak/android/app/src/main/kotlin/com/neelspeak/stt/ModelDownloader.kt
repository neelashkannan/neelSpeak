package com.neelspeak.stt

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.TimeUnit

/**
 * Resumable HTTPS download for the Parakeet sherpa-onnx bundle and the Gemma
 * MediaPipe .task file. Emits progress events as a Flow so the Flutter UI can
 * render a progress bar via EventChannel.
 *
 * The Parakeet bundle is shipped as a tar.bz2 archive in sherpa-onnx GitHub
 * Releases. We delegate extraction to ParakeetExtractor (companion implementation
 * left out of v1 — for now, ship a pre-extracted zip URL or use the helper
 * Python script under Scripts/ to host a flat directory).
 */
class ModelDownloader {
    private val http = OkHttpClient.Builder()
        .callTimeout(0, TimeUnit.MILLISECONDS) // streamed download; no overall cap
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    sealed class Progress {
        data class Downloading(val bytesRead: Long, val totalBytes: Long) : Progress()
        data class Extracting(val pct: Float) : Progress()
        object Done : Progress()
        data class Failed(val message: String) : Progress()
    }

    /**
     * Streams [url] into [dest]. If [dest] partially exists, resumes via
     * HTTP Range. Emits Downloading progress events.
     */
    fun download(url: String, dest: File): Flow<Progress> = flow {
        dest.parentFile?.mkdirs()
        val existing = if (dest.exists()) dest.length() else 0L
        val builder = Request.Builder().url(url)
        if (existing > 0) builder.header("Range", "bytes=$existing-")
        val req = builder.get().build()

        http.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful && resp.code != 206) {
                emit(Progress.Failed("HTTP ${resp.code}"))
                return@use
            }
            val body = resp.body ?: run { emit(Progress.Failed("empty body")); return@use }
            val totalReported = body.contentLength()
            val total = if (totalReported > 0) existing + totalReported else -1L
            val source = body.byteStream()
            val raf = RandomAccessFile(dest, "rw")
            raf.seek(existing)

            val buf = ByteArray(64 * 1024)
            var soFar = existing
            try {
                while (true) {
                    val n = source.read(buf)
                    if (n <= 0) break
                    raf.write(buf, 0, n)
                    soFar += n
                    emit(Progress.Downloading(soFar, total))
                }
                emit(Progress.Done)
                Log.i("NeelSpeak.Downloader", "downloaded $url -> ${dest.absolutePath} ($soFar bytes)")
            } finally {
                raf.close()
            }
        }
    }.flowOn(Dispatchers.IO)
}
