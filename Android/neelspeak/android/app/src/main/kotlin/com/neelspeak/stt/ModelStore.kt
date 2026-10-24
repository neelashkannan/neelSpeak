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

    /** Download target for the Parakeet tar.bz2. Kept in filesDir (not the
     *  cache, which Android may clear mid-download) so it can resume. */
    fun parakeetArchive(id: String = DEFAULT_PARAKEET_ID): File = File(root, "$id.tar.bz2.part")

    /** In-progress download of the LLM bundle; renamed to [llmFile] when complete. */
    fun llmPartialFile(id: String = DEFAULT_LLM_ID): File = File(llmFile(id).path + ".part")

    fun isParakeetInstalled(id: String = DEFAULT_PARAKEET_ID): Boolean {
        val d = parakeetDir(id)
        return PARQUET_REQUIRED_FILES.all { (name, size) ->
            val file = File(d, name)
            file.exists() && file.length() == size
        }
    }

    fun isLlmInstalled(id: String = DEFAULT_LLM_ID): Boolean = llmFile(id).exists() && llmFile(id).length() > 0

    companion object {
        const val DEFAULT_PARAKEET_ID = "sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8"
        const val DEFAULT_LLM_ID = "gemma-3-1b-it-int4"

        private val PARQUET_REQUIRED_FILES = mapOf(
            "encoder.int8.onnx" to 652_184_296L,
            "decoder.int8.onnx" to 7_257_753L,
            "joiner.int8.onnx" to 1_739_080L,
            "tokens.txt" to 9_384L,
        )
    }
}
