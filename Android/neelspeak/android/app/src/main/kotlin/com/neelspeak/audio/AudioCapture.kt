package com.neelspeak.audio

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import androidx.core.content.ContextCompat
import android.content.Context

/**
 * 16 kHz mono PCM16 microphone capture, drained as a FloatArray ready for the
 * sherpa-onnx Parakeet recognizer. Equivalent of AudioEngine.swift on macOS.
 *
 * One [AudioRecord] and one reader thread per recording; both are released in
 * [stopAndDrain] (also used to discard a recording), so the microphone is
 * never held between dictations.
 */
class AudioCapture(private val context: Context) {
    companion object {
        const val SAMPLE_RATE = 16_000
        private const val TAG = "NeelSpeak.AudioCapture"
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }

    private var record: AudioRecord? = null
    private var reader: Thread? = null
    private val lock = Object()
    private var samples = FloatArray(SAMPLE_RATE * 30) // ~30 s before the first grow
    private var count = 0

    val isRecording: Boolean get() = synchronized(lock) { record != null }

    fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    fun start() {
        if (!hasMicPermission()) throw SecurityException("Microphone permission not granted")
        synchronized(lock) {
            if (record != null) return
            count = 0
        }

        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
        if (minBuf <= 0) throw IllegalStateException("This device can't record 16 kHz mono audio")
        val bufSize = maxOf(minBuf, SAMPLE_RATE * 2) // ~1s buffer
        val rec = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            SAMPLE_RATE,
            CHANNEL,
            ENCODING,
            bufSize,
        )
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            throw IllegalStateException("Microphone unavailable")
        }
        try {
            rec.startRecording()
        } catch (t: Throwable) {
            rec.release()
            throw IllegalStateException("Microphone unavailable")
        }
        // Another app (a call, a recorder) can hold the mic; startRecording()
        // then returns without actually recording.
        if (rec.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            rec.release()
            throw IllegalStateException("Microphone is in use by another app")
        }

        val thread = Thread({ readLoop(rec, bufSize / 2) }, "NeelSpeak-mic")
        synchronized(lock) {
            record = rec
            reader = thread
        }
        thread.start()
        Log.i(TAG, "started capture @${SAMPLE_RATE}Hz mono")
    }

    private fun readLoop(rec: AudioRecord, chunk: Int) {
        val buffer = ShortArray(chunk)
        while (rec.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
            val read = try {
                rec.read(buffer, 0, buffer.size)
            } catch (_: Throwable) {
                break
            }
            if (read < 0) break // ERROR_INVALID_OPERATION / ERROR_DEAD_OBJECT
            if (read == 0) continue
            synchronized(lock) {
                if (count + read > samples.size) {
                    samples = samples.copyOf(maxOf(samples.size * 2, count + read))
                }
                for (i in 0 until read) {
                    samples[count + i] = buffer[i] / 32768f
                }
                count += read
            }
        }
    }

    /** Stops capture, releases the mic, and returns everything recorded. */
    fun stopAndDrain(): FloatArray {
        val (rec, thread) = synchronized(lock) {
            val r = record ?: return FloatArray(0)
            record = null
            val t = reader
            reader = null
            r to t
        }
        try {
            rec.stop()
        } catch (_: IllegalStateException) {
            // already stopped
        }
        try {
            thread?.join(1_000)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        rec.release()
        return synchronized(lock) {
            val out = samples.copyOf(count)
            count = 0
            if (samples.size > SAMPLE_RATE * 30) samples = FloatArray(SAMPLE_RATE * 30)
            out
        }
    }
}
