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
import java.io.IOException
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

    /** Streams [url] into [dest], optionally resuming via HTTP Range if partial. */
    fun download(url: String, dest: File, resume: Boolean = true): Flow<Progress> = flow {
        dest.parentFile?.mkdirs()
        val existing = if (resume && dest.exists()) dest.length() else 0L
        val builder = Request.Builder().url(url)
        if (existing > 0) builder.header("Range", "bytes=$existing-")
        val req = builder.get().build()

        val response = try {
            http.newCall(req).execute()
        } catch (e: IOException) {
            emit(Progress.Failed("Network error: ${e.message ?: "connection failed"}"))
            return@flow
        }
        response.use { resp ->
            if (resp.code == 416 && existing > 0) {
                // The partial file is already as long as (or longer than) the
                // remote one. Start over rather than trust it.
                dest.delete()
                emit(Progress.Failed("Download restarted — please try again"))
                return@use
            }
            if (!resp.isSuccessful && resp.code != 206) {
                emit(Progress.Failed("HTTP ${resp.code}"))
                return@use
            }
            val body = resp.body ?: run { emit(Progress.Failed("empty body")); return@use }
            val resumed = existing > 0 && resp.code == 206
            val startOffset = if (resumed) existing else 0L
            val totalReported = body.contentLength()
            val total = when {
                totalReported <= 0 -> -1L
                resumed -> startOffset + totalReported
                else -> totalReported
            }
            val raf = RandomAccessFile(dest, "rw")
            if (!resumed) {
                raf.setLength(0)
            }
            raf.seek(startOffset)
            val buf = ByteArray(64 * 1024)
            var soFar = startOffset
            try {
                val source = body.byteStream()
                var networkError: IOException? = null
                while (true) {
                    val n = try {
                        source.read(buf)
                    } catch (e: IOException) {
                        networkError = e
                        break
                    }
                    if (n <= 0) break
                    raf.write(buf, 0, n)
                    soFar += n
                    emit(Progress.Downloading(soFar, total))
                }
                if (networkError != null || (total > 0 && soFar < total)) {
                    // Keep the partial file: the next attempt resumes from it.
                    emit(Progress.Failed("Download interrupted at ${soFar / (1024 * 1024)} MB. Try again to resume."))
                    return@use
                }
                if (total > 0 && soFar != total) {
                    dest.delete()
                    emit(Progress.Failed("Download incomplete: expected $total bytes, got $soFar"))
                    return@use
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
     * Downloading → Extracting; the caller validates [destDir] and reports Done.
     *
     * [archiveFile] is kept between attempts so an interrupted download
     * resumes. Extraction goes to a sibling ".partial" directory that only
     * replaces [destDir] once every entry is written, so a half-extracted
     * model is never visible at the final path.
     */
    fun downloadAndExtractTarBz2(url: String, destDir: File, archiveFile: File): Flow<Progress> = flow {
        // Phase 1: download (resuming) to archiveFile
        var failed = false
        download(url, archiveFile, resume = true).collect { p ->
            if (p is Progress.Done) return@collect // extraction comes next
            emit(p)
            if (p is Progress.Failed) failed = true
        }
        if (failed) return@flow
        // Phase 2: extract into a staging directory, then swap it in
        val staging = File(destDir.parentFile, destDir.name + ".partial")
        try {
            staging.deleteRecursively()
            staging.mkdirs()
            val stagingRoot = staging.canonicalPath + File.separator
            BufferedInputStream(FileInputStream(archiveFile)).use { rawIn ->
                BZip2CompressorInputStream(rawIn).use { bzIn ->
                    TarArchiveInputStream(bzIn).use { tarIn ->
                        var entry = tarIn.nextEntry
                        var fileCount = 0
                        while (entry != null) {
                            if (!entry.isDirectory) {
                                // Flatten: strip the leading archive folder
                                val name = entry.name.substringAfter('/', entry.name)
                                val outFile = File(staging, name)
                                if (!outFile.canonicalPath.startsWith(stagingRoot)) {
                                    throw IllegalStateException("Unexpected path in archive: ${entry.name}")
                                }
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
            destDir.deleteRecursively()
            if (!staging.renameTo(destDir)) throw IllegalStateException("Could not move the model into place")
            archiveFile.delete()
        } catch (e: Throwable) {
            Log.e("NeelSpeak.Downloader", "extract failed: ${e.message}", e)
            staging.deleteRecursively()
            if (e is kotlinx.coroutines.CancellationException) throw e
            // A corrupt archive would fail the same way on every retry.
            archiveFile.delete()
            emit(Progress.Failed("Extract failed: ${e.message}"))
        }
    }.flowOn(Dispatchers.IO)
}
