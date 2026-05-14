package com.neelspeak.stt

import android.content.Context
import java.io.File

/**
 * On-disk locations for STT and LLM model artifacts. Mirrors the macOS layout
 * under `~/Library/Application Support/NeelSpeak/Models/FluidAudio/...`.
 */
class ModelStore(private val context: Context) {
    private val root: File get() = File(context.filesDir, "models").apply { mkdirs() }

    /** Directory containing encoder/decoder/joiner/tokens for the sherpa-onnx Parakeet model. */
    fun parakeetDir(id: String = DEFAULT_PARAKEET_ID): File = File(root, id).apply { mkdirs() }

    /** Path to the on-device cleanup LLM .task bundle (MediaPipe LLM Inference). */
    fun llmFile(id: String = DEFAULT_LLM_ID): File = File(File(root, "llm").apply { mkdirs() }, "$id.task")

    fun isParakeetInstalled(id: String = DEFAULT_PARAKEET_ID): Boolean {
        val d = parakeetDir(id)
        return listOf("encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt")
            .all { File(d, it).exists() }
    }

    fun isLlmInstalled(id: String = DEFAULT_LLM_ID): Boolean = llmFile(id).exists() && llmFile(id).length() > 0

    companion object {
        const val DEFAULT_PARAKEET_ID = "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8"
        const val DEFAULT_LLM_ID = "gemma-3-1b-it-int4"
    }
}
