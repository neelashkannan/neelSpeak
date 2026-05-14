package com.neelspeak.stt

import android.content.Context
import android.util.Log
import java.io.File

/**
 * Speech-to-text engine interface. The production impl wraps sherpa-onnx's
 * `OfflineRecognizer` configured for Parakeet TDT. Kept behind an interface so
 * the IME can render a stub when models aren't present yet.
 */
interface SttEngine {
    fun isReady(): Boolean
    suspend fun transcribe(samples: FloatArray, sampleRate: Int): String
    fun release()
}

/**
 * sherpa-onnx Parakeet implementation. Uses reflection so the module compiles
 * even before the user drops `sherpa-onnx-X.Y.Z.aar` into android/app/libs/.
 * Once the AAR is present, this class loads `OfflineRecognizer` via the
 * official Kotlin bindings (package `com.k2fsa.sherpa.onnx`).
 */
class ParakeetSherpaEngine(
    private val context: Context,
    private val modelStore: ModelStore,
) : SttEngine {
    private var recognizer: Any? = null

    override fun isReady(): Boolean = recognizer != null

    fun load(): Boolean {
        if (recognizer != null) return true
        if (!modelStore.isParakeetInstalled()) return false
        return try {
            val dir = modelStore.parakeetDir().absolutePath
            // sherpa-onnx Kotlin API (matches the prebuilt AAR):
            //   val cfg = OfflineRecognizerConfig(...).apply { modelConfig.transducer.encoder = ... }
            //   val recognizer = OfflineRecognizer(assetManager = null, config = cfg)
            // We invoke via reflection to keep this file compilable without the
            // AAR present. See README for the exact AAR drop.
            val modelCfgClass = Class.forName("com.k2fsa.sherpa.onnx.OfflineTransducerModelConfig")
            val modelCfg = modelCfgClass.getDeclaredConstructor().newInstance()
            modelCfgClass.getField("encoder").set(modelCfg, File(dir, "encoder.int8.onnx").absolutePath)
            modelCfgClass.getField("decoder").set(modelCfg, File(dir, "decoder.int8.onnx").absolutePath)
            modelCfgClass.getField("joiner").set(modelCfg, File(dir, "joiner.int8.onnx").absolutePath)

            val omcClass = Class.forName("com.k2fsa.sherpa.onnx.OfflineModelConfig")
            val omc = omcClass.getDeclaredConstructor().newInstance()
            omcClass.getField("transducer").set(omc, modelCfg)
            omcClass.getField("tokens").set(omc, File(dir, "tokens.txt").absolutePath)
            omcClass.getField("modelType").set(omc, "nemo_transducer")
            omcClass.getField("numThreads").set(omc, 2)

            val recCfgClass = Class.forName("com.k2fsa.sherpa.onnx.OfflineRecognizerConfig")
            val recCfg = recCfgClass.getDeclaredConstructor().newInstance()
            recCfgClass.getField("modelConfig").set(recCfg, omc)

            val recClass = Class.forName("com.k2fsa.sherpa.onnx.OfflineRecognizer")
            val rec = recClass.getDeclaredConstructor(recCfgClass).newInstance(recCfg)
            recognizer = rec
            true
        } catch (e: Throwable) {
            Log.e("NeelSpeak.STT", "Parakeet load failed: ${e.message}", e)
            recognizer = null
            false
        }
    }

    override suspend fun transcribe(samples: FloatArray, sampleRate: Int): String {
        if (!load()) return ""
        return try {
            val rec = recognizer ?: return ""
            val recClass = rec.javaClass
            val stream = recClass.getMethod("createStream").invoke(rec)
            val streamClass = stream!!.javaClass
            streamClass.getMethod("acceptWaveform", FloatArray::class.java, Int::class.javaPrimitiveType)
                .invoke(stream, samples, sampleRate)
            recClass.getMethod("decode", streamClass).invoke(rec, stream)
            val result = recClass.getMethod("getResult", streamClass).invoke(rec, stream)
            val text = result?.javaClass?.getMethod("getText")?.invoke(result) as? String
            // Release the stream
            try { streamClass.getMethod("release").invoke(stream) } catch (_: Throwable) {}
            text.orEmpty()
        } catch (e: Throwable) {
            Log.e("NeelSpeak.STT", "transcribe failed: ${e.message}", e)
            ""
        }
    }

    override fun release() {
        try {
            recognizer?.javaClass?.getMethod("release")?.invoke(recognizer)
        } catch (_: Throwable) {}
        recognizer = null
    }
}
