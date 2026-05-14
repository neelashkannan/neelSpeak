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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

/**
 * 16 kHz mono PCM16 microphone capture, drained as a FloatArray ready for the
 * sherpa-onnx Parakeet recognizer. Equivalent of AudioEngine.swift on macOS.
 */
class AudioCapture(private val context: Context) {
    companion object {
        const val SAMPLE_RATE = 16_000
        private const val TAG = "NeelSpeak.AudioCapture"
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }

    private var record: AudioRecord? = null
    private var job: Job? = null
    private val samples = ArrayList<Float>(SAMPLE_RATE * 30) // ~30s headroom
    private val lock = Object()

    fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    fun start() {
        if (!hasMicPermission()) error("RECORD_AUDIO permission not granted")
        if (record != null) return

        val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
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
            error("AudioRecord init failed")
        }
        record = rec
        synchronized(lock) { samples.clear() }
        rec.startRecording()

        job = CoroutineScope(Dispatchers.IO).launch {
            val buffer = ShortArray(bufSize / 2)
            while (rec.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                val read = rec.read(buffer, 0, buffer.size)
                if (read <= 0) continue
                synchronized(lock) {
                    for (i in 0 until read) {
                        samples.add(buffer[i].toFloat() / 32768f)
                    }
                }
            }
        }
        Log.i(TAG, "started capture @${SAMPLE_RATE}Hz mono")
    }

    fun stopAndDrain(): FloatArray {
        val rec = record ?: return FloatArray(0)
        try {
            rec.stop()
        } catch (_: IllegalStateException) {
            // already stopped
        }
        runBlocking { job?.cancelAndJoin() }
        rec.release()
        record = null
        job = null
        return synchronized(lock) { samples.toFloatArray().also { samples.clear() } }
    }
}
