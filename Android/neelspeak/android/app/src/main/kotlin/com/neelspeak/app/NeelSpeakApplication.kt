package com.neelspeak.app

import android.app.Application
import com.neelspeak.coordinator.DictationCoordinator

/**
 * Application class. Holds the process-wide [DictationCoordinator] so the IME
 * service and Flutter MainActivity share one audio/STT/cleanup pipeline.
 */
class NeelSpeakApplication : Application() {
    lateinit var coordinator: DictationCoordinator
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        coordinator = DictationCoordinator(this)
    }

    companion object {
        @Volatile private var instance: NeelSpeakApplication? = null
        val app: NeelSpeakApplication get() = instance!!
    }
}
