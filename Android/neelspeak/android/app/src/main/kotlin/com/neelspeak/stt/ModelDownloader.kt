package com.neelspeak.stt

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import okhttp3.OkHttpClient
import okhttp3.Request
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.util.concurrent.TimeUnit

/**
 * Resumable HTTPS download + tar.bz2 extraction for the sherpa-onnx Parakeet
 * bundle. Also handles plain-file downloads for the on-device LLM .task bundle.
 */
class ModelDownloader {
    private val http = OkHttpClient.Builder()
        .callTimeout(0, TimeUnit.MILLISECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    sealed class Progress {
        data class Downloading(val bytesRead: Long, val totalBytes: Long) : Progress()
        data class Extracting(val pct: Float) : Progress()
        object Done : Progress()
        data class Failed(val message: String) : Progress()
    }

    /** Streams [url] into [dest], resuming via HTTP Range if partial. */
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
            val raf = RandomAccessFile(dest, "rw")
            raf.seek(existing)
            val buf = ByteArray(64 * 1024)
            var soFar = existing
            try {
                val source = body.byteStream()
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

    /**
     * Download a tar.bz2 archive and extract the inner contents into [destDir].
     * The archive root folder (e.g. "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2/")
     * is flattened so the files land directly in [destDir]. Progress alternates
     * Downloading → Extracting → Done.
     */
    fun downloadAndExtractTarBz2(url: String, destDir: File, tmpFile: File): Flow<Progress> = flow {
        // Phase 1: download to tmpFile
        var failed = false
        download(url, tmpFile).collect { p ->
            if (p is Progress.Done) return@collect // we'll re-emit Done after extraction
            emit(p)
            if (p is Progress.Failed) failed = true
        }
        if (failed) return@flow
        // Phase 2: extract
        try {
            destDir.mkdirs()
            BufferedInputStream(FileInputStream(tmpFile)).use { rawIn ->
                BZip2CompressorInputStream(rawIn).use { bzIn ->
                    TarArchiveInputStream(bzIn).use { tarIn ->
                        var entry = tarIn.nextEntry
                        var fileCount = 0
                        while (entry != null) {
                            if (!entry.isDirectory) {
                                // Flatten: strip the leading archive folder
                                val name = entry.name.substringAfter('/', entry.name)
                                val outFile = File(destDir, name)
                                outFile.parentFile?.mkdirs()
                                FileOutputStream(outFile).use { out ->
                                    tarIn.copyTo(out, bufferSize = 64 * 1024)
                                }
                                fileCount++
                                emit(Progress.Extracting(fileCount.toFloat()))
                            }
                            entry = tarIn.nextEntry
                        }
                    }
                }
            }
            tmpFile.delete()
            emit(Progress.Done)
        } catch (e: Throwable) {
            Log.e("NeelSpeak.Downloader", "extract failed: ${e.message}", e)
            emit(Progress.Failed("Extract failed: ${e.message}"))
        }
    }.flowOn(Dispatchers.IO)
}
