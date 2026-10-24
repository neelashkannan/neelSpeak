package com.neelspeak.stt

import android.content.Context
import android.util.Log
import com.k2fsa.sherpa.onnx.OfflineModelConfig
import com.k2fsa.sherpa.onnx.OfflineRecognizer
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig
import com.k2fsa.sherpa.onnx.OfflineTransducerModelConfig
import java.io.File

/**
 * Speech-to-text engine interface. The production impl wraps sherpa-onnx's
 * `OfflineRecognizer` configured for Parakeet TDT. Kept behind an interface so
 * the IME can render a stub when models aren't present yet.
 */
interface SttEngine {
    fun isReady(): Boolean
    fun load(): Boolean
    suspend fun transcribe(samples: FloatArray, sampleRate: Int): String
    fun release()
}

/**
 * sherpa-onnx Parakeet implementation using the official Kotlin bindings.
 */
class ParakeetSherpaEngine(
    private val context: Context,
    private val modelStore: ModelStore,
) : SttEngine {
    private var recognizer: OfflineRecognizer? = null

    override fun isReady(): Boolean = recognizer != null

    @Synchronized
    override fun load(): Boolean {
        if (recognizer != null) return true
        if (!modelStore.isParakeetInstalled()) return false
        return try {
            val started = System.currentTimeMillis()
            val dir = modelStore.parakeetDir().absolutePath
            val transducer = OfflineTransducerModelConfig(
                encoder = File(dir, "encoder.int8.onnx").absolutePath,
                decoder = File(dir, "decoder.int8.onnx").absolutePath,
                joiner = File(dir, "joiner.int8.onnx").absolutePath,
            )
            val modelConfig = OfflineModelConfig(
                transducer = transducer,
                tokens = File(dir, "tokens.txt").absolutePath,
                modelType = "nemo_transducer",
                numThreads = 4,
                provider = "cpu",
            )
            val recognizerConfig = OfflineRecognizerConfig(modelConfig = modelConfig)
            recognizer = OfflineRecognizer(null, recognizerConfig)
            Log.i("NeelSpeak.STT", "Parakeet recognizer loaded in ${System.currentTimeMillis() - started} ms")
            true
        } catch (e: Throwable) {
            Log.e("NeelSpeak.STT", "Parakeet load failed: ${e.message}", e)
            recognizer = null
            false
        }
    }

    /** Decodes [samples]. Throws when the model can't be loaded or decoding
     *  fails, so the caller can surface it instead of committing nothing. */
    override suspend fun transcribe(samples: FloatArray, sampleRate: Int): String {
        if (!load()) throw IllegalStateException("Speech model could not be loaded. Open NeelSpeak to download it again.")
        return synchronized(this) {
            val rec = recognizer ?: throw IllegalStateException("Speech model is not loaded")
            val started = System.currentTimeMillis()
            val stream = rec.createStream()
            try {
                stream.acceptWaveform(samples, sampleRate)
                rec.decode(stream)
                val text = rec.getResult(stream).text
                Log.i("NeelSpeak.STT", "Transcribed ${samples.size} samples in ${System.currentTimeMillis() - started} ms")
                text
            } finally {
                stream.release()
            }
        }
    }

    @Synchronized
    override fun release() {
        try {
            recognizer?.release()
        } catch (_: Throwable) {}
        recognizer = null
    }
}
