package com.neelspeak.coordinator

import android.content.Context
import android.os.SystemClock
import android.util.Log
import com.neelspeak.audio.AudioCapture
import com.neelspeak.cleanup.CleanupMode
import com.neelspeak.cleanup.LlmTranscriptCleaner
import com.neelspeak.cleanup.TranscriptCorrector
import com.neelspeak.prefs.Settings
import com.neelspeak.prefs.SettingsKeys
import com.neelspeak.stt.ModelStore
import com.neelspeak.stt.ParakeetSherpaEngine
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Application-scoped singleton that owns the dictation pipeline. Both the IME
 * service and the Flutter MainActivity reach it through
 * `NeelSpeakApplication.coordinator`. Mirrors DictationCoordinator.swift —
 * Recording → Transcribing → Cleaning → emit transcript → Idle. The IME
 * subscribes to [state] and to [results] to call commitText().
 *
 * begin/end/cancel are synchronized so a press from the IME and a call from
 * the settings UI can't interleave. Each dictation gets a generation number;
 * a cancelled or superseded pipeline never emits its result.
 */
class DictationCoordinator(private val appContext: Context) {
    /** Who started a dictation — results are only committed by the keyboard
     *  for keyboard dictations; the in-app test gets its own. */
    enum class Origin { Keyboard, App }

    /** [text] is empty when the dictation was discarded or failed. */
    data class Result(val text: String, val origin: Origin)

    private val audio = AudioCapture(appContext)
    private val store = ModelStore(appContext)
    private val stt = ParakeetSherpaEngine(appContext, store)
    private val cleaner = LlmTranscriptCleaner(appContext)
    private val settings = Settings(appContext)

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val _state = MutableStateFlow<DictationState>(DictationState.Idle)
    val state: StateFlow<DictationState> = _state.asStateFlow()

    private val _results = MutableSharedFlow<Result>(extraBufferCapacity = 8)
    val results = _results.asSharedFlow()

    /** Shown under the pill after a cleanup failure: the raw text was
     *  inserted instead. Cleared by the next successful cleanup. */
    private val _notice = MutableStateFlow<String?>(null)
    val notice: StateFlow<String?> = _notice.asStateFlow()

    private var inFlight: Job? = null
    private var generation = 0L
    private var origin = Origin.Keyboard
    private var pressedAt = 0L

    init {
        if (!store.isParakeetInstalled()) {
            _state.value = DictationState.SetupRequired
        }
    }

    /** Preloads the recognizer. Leaves the state alone if a dictation is running. */
    fun warmStt(): Boolean {
        if (!store.isParakeetInstalled()) {
            setIfQuiet(DictationState.SetupRequired)
            return false
        }
        setIfQuiet(DictationState.Warming)
        return if (stt.load()) {
            setIfQuiet(DictationState.Idle, onlyFrom = DictationState.Warming)
            true
        } else {
            setIfQuiet(DictationState.Error("Speech model could not be loaded. Open NeelSpeak to download it again."))
            false
        }
    }

    @Synchronized
    fun beginDictation(from: Origin = Origin.Keyboard) {
        val current = _state.value
        val ready = current is DictationState.Idle ||
            current is DictationState.Error ||
            current is DictationState.SetupRequired
        if (!ready) return
        if (!store.isParakeetInstalled()) {
            _state.value = DictationState.SetupRequired
            return
        }
        if (!audio.hasMicPermission()) {
            _state.value = DictationState.Error(MIC_DENIED)
            return
        }
        try {
            audio.start()
            origin = from
            pressedAt = SystemClock.elapsedRealtime()
            _state.value = DictationState.Recording
        } catch (t: Throwable) {
            Log.w(TAG, "mic start failed: ${t.message}")
            _state.value = DictationState.Error(t.message ?: "Microphone unavailable")
        }
    }

    @Synchronized
    fun endDictation() {
        if (_state.value !is DictationState.Recording) return
        val samples = audio.stopAndDrain()
        val gen = ++generation
        val from = origin
        val heldMs = SystemClock.elapsedRealtime() - pressedAt

        // An accidental tap or a hold too short to contain a word: discard
        // quietly rather than run the model on silence.
        if (heldMs < MIN_HOLD_MS || samples.size < MIN_SAMPLES) {
            _state.value = DictationState.Idle
            _results.tryEmit(Result("", from))
            return
        }

        _state.value = DictationState.Transcribing
        inFlight?.cancel()
        inFlight = scope.launch {
            try {
                val raw = stt.transcribe(samples, AudioCapture.SAMPLE_RATE)
                val corrected = TranscriptCorrector.correct(raw)
                val mode = CleanupMode.fromRaw(settings.getString(SettingsKeys.CLEANUP_MODE))
                val cleaned = if (mode == CleanupMode.Off || corrected.isEmpty()) {
                    corrected
                } else {
                    if (!transition(gen, DictationState.Cleaning)) return@launch
                    cleanOrFallBack(corrected, mode)
                }
                finish(gen, cleaned, from)
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                Log.e(TAG, "pipeline failed: ${t.javaClass.simpleName}: ${t.message}")
                if (transition(gen, DictationState.Error(t.message ?: "Transcription failed"))) {
                    _results.tryEmit(Result("", from))
                }
            }
        }
    }

    /**
     * Throws away the current dictation: stops the mic if recording, or drops
     * the result of a transcription/cleanup that is still running.
     */
    @Synchronized
    fun cancelDictation() {
        when (_state.value) {
            is DictationState.Recording -> {
                audio.stopAndDrain()
                generation++
                _state.value = DictationState.Idle
                _results.tryEmit(Result("", origin))
            }
            is DictationState.Transcribing, is DictationState.Cleaning -> {
                generation++
                inFlight?.cancel()
                inFlight = null
                _state.value = DictationState.Idle
                _results.tryEmit(Result("", origin))
            }
            else -> Unit
        }
    }

    private suspend fun cleanOrFallBack(corrected: String, mode: CleanupMode): String =
        try {
            val out = cleaner.clean(corrected, mode)
            if (_notice.value != null || settings.getString(SettingsKeys.CLEANUP_LAST_ERROR).isNotEmpty()) {
                _notice.value = null
                settings.set(SettingsKeys.CLEANUP_LAST_ERROR, null)
                settings.set(SettingsKeys.CLEANUP_LAST_ERROR_AT, null)
            }
            out.ifBlank { corrected }
        } catch (e: CancellationException) {
            throw e
        } catch (t: Throwable) {
            // Keep the dictation: insert the corrected transcript and tell the
            // user why it wasn't cleaned (bad key, retired model, offline…).
            val reason = LlmTranscriptCleaner.describeFailure(t)
            Log.w(TAG, "cleanup failed, inserting uncleaned text: $reason")
            settings.set(SettingsKeys.CLEANUP_LAST_ERROR, reason)
            settings.set(SettingsKeys.CLEANUP_LAST_ERROR_AT, System.currentTimeMillis())
            _notice.value = "Cleanup failed — inserted the raw transcript. $reason"
            corrected
        }

    @Synchronized
    private fun transition(gen: Long, next: DictationState): Boolean {
        if (gen != generation) return false
        _state.value = next
        return true
    }

    @Synchronized
    private fun finish(gen: Long, text: String, from: Origin) {
        if (gen != generation) return
        _results.tryEmit(Result(text, from))
        _state.value = DictationState.Idle
    }

    @Synchronized
    private fun setIfQuiet(next: DictationState, onlyFrom: DictationState? = null) {
        val current = _state.value
        if (onlyFrom != null && current != onlyFrom) return
        val quiet = current is DictationState.Idle || current is DictationState.SetupRequired ||
            current is DictationState.Error || current is DictationState.Warming
        if (quiet) _state.value = next
    }

    fun dismissNotice() { _notice.value = null }

    /** Recover from an error without a new dictation (e.g. the pill was tapped). */
    @Synchronized
    fun clearError() {
        if (_state.value is DictationState.Error) {
            _state.value = if (store.isParakeetInstalled()) DictationState.Idle else DictationState.SetupRequired
        }
    }

    val needsApp: Boolean
        get() = when (val s = _state.value) {
            is DictationState.SetupRequired -> true
            is DictationState.Error -> s.message == MIC_DENIED || !store.isParakeetInstalled()
            else -> false
        }

    /** Called after a successful model download. */
    @Synchronized
    fun onModelInstalled() {
        if (_state.value is DictationState.SetupRequired) _state.value = DictationState.Idle
    }

    /** Called before the model files are deleted, so the recognizer lets go of them. */
    @Synchronized
    fun onModelRemoved() {
        cancelDictation()
        stt.release()
        _state.value = DictationState.SetupRequired
    }

    fun markIdle() { _state.value = DictationState.Idle }
    fun markSetupRequired() { _state.value = DictationState.SetupRequired }
    fun release() { stt.release() }

    companion object {
        private const val TAG = "NeelSpeak.Coord"
        /** Holds shorter than this are treated as an accidental tap. */
        const val MIN_HOLD_MS = 250L
        /** Less audio than this (0.3 s at 16 kHz) can't contain a word. */
        const val MIN_SAMPLES = 4_800
        const val MIC_DENIED = "Microphone permission is off. Tap to open NeelSpeak."
    }
}
