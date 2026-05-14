package com.neelspeak.coordinator

/** Mirrors `DictationCoordinator.State` from
 *  Sources/VoiceTyper/Pipeline/DictationCoordinator.swift. */
sealed class DictationState {
    object SetupRequired : DictationState()
    data class DownloadingModel(val progress: Float) : DictationState()
    object Warming : DictationState()
    object Idle : DictationState()
    object Recording : DictationState()
    object Transcribing : DictationState()
    object Cleaning : DictationState()
    data class Error(val message: String) : DictationState()

    val label: String
        get() = when (this) {
            SetupRequired -> "setupRequired"
            is DownloadingModel -> "downloadingModel"
            Warming -> "warming"
            Idle -> "idle"
            Recording -> "recording"
            Transcribing -> "transcribing"
            Cleaning -> "cleaning"
            is Error -> "error"
        }
}
