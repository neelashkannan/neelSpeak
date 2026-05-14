package com.neelspeak.cleanup

import android.content.Context
import android.util.Log
import com.neelspeak.stt.ModelStore
import java.io.File

/**
 * On-device cleanup via MediaPipe LLM Inference (Gemma 3 1B int4). The
 * `.task` bundle must already be downloaded into [ModelStore.llmFile]. We use
 * reflection to keep this file compilable when the `tasks-genai` dependency
 * isn't fully resolved in the IDE — the runtime class is
 * `com.google.mediapipe.tasks.genai.llminference.LlmInference`.
 */
class OnDeviceLlmClient(private val context: Context, private val modelStore: ModelStore) {
    private var llmInference: Any? = null

    fun isReady(): Boolean = modelStore.isLlmInstalled()

    fun clean(text: String, mode: CleanupMode): String {
        if (mode == CleanupMode.Off) return text
        val modelFile: File = modelStore.llmFile()
        if (!modelFile.exists()) throw CleanupHttpException(
            "On-device model not installed. Download it from NeelSpeak settings."
        )
        ensureLoaded(modelFile)
        val inf = llmInference ?: throw CleanupHttpException("MediaPipe LLM not loaded")

        val prompt = buildGemmaPrompt(text, mode)
        return try {
            val started = System.currentTimeMillis()
            val out = inf.javaClass.getMethod("generateResponse", String::class.java).invoke(inf, prompt) as? String
                ?: ""
            Log.i("NeelSpeak.Cleanup", "on-device gemma ${(System.currentTimeMillis() - started)}ms")
            out
        } catch (e: Throwable) {
            throw CleanupHttpException("LLM inference failed: ${e.message}")
        }
    }

    private fun ensureLoaded(modelFile: File) {
        if (llmInference != null) return
        try {
            val optionsBuilderClass = Class.forName(
                "com.google.mediapipe.tasks.genai.llminference.LlmInference\$LlmInferenceOptions\$Builder"
            )
            val optionsClass = Class.forName(
                "com.google.mediapipe.tasks.genai.llminference.LlmInference\$LlmInferenceOptions"
            )
            val optionsCompanion = Class.forName(
                "com.google.mediapipe.tasks.genai.llminference.LlmInference\$LlmInferenceOptions"
            ).getMethod("builder").invoke(null)
            optionsBuilderClass.getMethod("setModelPath", String::class.java)
                .invoke(optionsCompanion, modelFile.absolutePath)
            optionsBuilderClass.getMethod("setMaxTokens", Int::class.javaPrimitiveType)
                .invoke(optionsCompanion, 512)
            optionsBuilderClass.getMethod("setMaxTopK", Int::class.javaPrimitiveType)
                .invoke(optionsCompanion, 40)
            val options = optionsBuilderClass.getMethod("build").invoke(optionsCompanion)

            val infClass = Class.forName("com.google.mediapipe.tasks.genai.llminference.LlmInference")
            llmInference = infClass.getMethod("createFromOptions", Context::class.java, optionsClass)
                .invoke(null, context, options)
        } catch (e: Throwable) {
            Log.e("NeelSpeak.Cleanup", "MediaPipe load failed: ${e.message}", e)
            throw CleanupHttpException("On-device LLM failed to load: ${e.message}")
        }
    }

    /** Gemma chat format. The system prompt + few-shot pairs are flattened
     *  into the model-turn template Gemma was instruction-tuned with. */
    private fun buildGemmaPrompt(text: String, mode: CleanupMode): String {
        val sb = StringBuilder()
        sb.append("<start_of_turn>system\n").append(mode.systemPrompt).append("<end_of_turn>\n")
        for ((userEx, asstEx) in mode.fewShotExamples) {
            sb.append("<start_of_turn>user\n").append(CloudHttp.wrapTranscript(userEx)).append("<end_of_turn>\n")
            sb.append("<start_of_turn>model\n").append(asstEx).append("<end_of_turn>\n")
        }
        sb.append("<start_of_turn>user\n").append(CloudHttp.wrapTranscript(text)).append("<end_of_turn>\n")
        sb.append("<start_of_turn>model\n")
        return sb.toString()
    }

    fun release() {
        try {
            llmInference?.javaClass?.getMethod("close")?.invoke(llmInference)
        } catch (_: Throwable) {}
        llmInference = null
    }
}
