package com.neelspeak.coordinator

import android.content.Context
import android.util.Log
import com.neelspeak.audio.AudioCapture
import com.neelspeak.cleanup.CleanupMode
import com.neelspeak.cleanup.LlmTranscriptCleaner
import com.neelspeak.cleanup.TranscriptCorrector
import com.neelspeak.prefs.Settings
import com.neelspeak.prefs.SettingsKeys
import com.neelspeak.stt.ModelStore
import com.neelspeak.stt.ParakeetSherpaEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch

/**
 * Application-scoped singleton that owns the dictation pipeline. Both the IME
 * service and the Flutter MainActivity reach it through
 * `NeelSpeakApplication.coordinator`. Mirrors DictationCoordinator.swift —
 * Recording → Transcribing → Cleaning → emit transcript → Idle. The IME
 * subscribes to [state] and to [transcripts] to call commitText().
 */
class DictationCoordinator(private val appContext: Context) {
    private val audio = AudioCapture(appContext)
    private val store = ModelStore(appContext)
    private val stt = ParakeetSherpaEngine(appContext, store)
    private val cleaner = LlmTranscriptCleaner(appContext)
    private val settings = Settings(appContext)

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val _state = MutableStateFlow<DictationState>(DictationState.Idle)
    val state: StateFlow<DictationState> = _state.asStateFlow()

    private val _transcripts = MutableSharedFlow<String>(extraBufferCapacity = 4)
    val transcripts = _transcripts.asSharedFlow()

    private var inFlight: Job? = null

    init {
        if (!store.isParakeetInstalled()) {
            _state.value = DictationState.SetupRequired
        }
    }

    fun warmStt(): Boolean {
        if (!store.isParakeetInstalled()) {
            _state.value = DictationState.SetupRequired
            return false
        }
        _state.value = DictationState.Warming
        return if (stt.load()) {
            _state.value = DictationState.Idle
            true
        } else {
            _state.value = DictationState.Error("Parakeet runtime is missing or could not load")
            false
        }
    }

    fun beginDictation() {
        if (_state.value is DictationState.SetupRequired && store.isParakeetInstalled()) {
            _state.value = DictationState.Idle
        }
        if (_state.value !is DictationState.Idle) return
        if (!audio.hasMicPermission()) {
            _state.value = DictationState.Error("Microphone permission denied")
            return
        }
        if (!store.isParakeetInstalled()) {
            _state.value = DictationState.SetupRequired
            return
        }
        try {
            audio.start()
            _state.value = DictationState.Recording
        } catch (t: Throwable) {
            _state.value = DictationState.Error("mic: ${t.message}")
        }
    }

    fun endDictation() {
        if (_state.value !is DictationState.Recording) return
        val samples = audio.stopAndDrain()
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
                    _state.value = DictationState.Cleaning
                    cleaner.clean(corrected, mode)
                }
                _transcripts.emit(cleaned)
                _state.value = DictationState.Idle
            } catch (t: Throwable) {
                Log.e("NeelSpeak.Coord", "pipeline failed: ${t.message}", t)
                _state.value = DictationState.Error(t.message ?: "unknown error")
            }
        }
    }

    fun markIdle() { _state.value = DictationState.Idle }
    fun markSetupRequired() { _state.value = DictationState.SetupRequired }
    fun release() { stt.release() }
}
