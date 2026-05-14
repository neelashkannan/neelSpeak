package com.neelspeak.ime

import android.content.Context
import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.InputMethodManager
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import com.neelspeak.app.NeelSpeakApplication
import com.neelspeak.coordinator.DictationState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

/**
 * The Android IME. Replaces the system keyboard with a single press-and-hold
 * mic pill. When the coordinator emits a cleaned transcript, we forward it
 * straight into the focused text field via InputConnection.commitText.
 *
 * Mirrors the role of HotkeyManager + TextInjector + DictationCoordinator's UI
 * surface on macOS — gesture in, text out.
 */
class NeelSpeakImeService : InputMethodService(),
    LifecycleOwner,
    ViewModelStoreOwner,
    SavedStateRegistryOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this)
    private val vmStore = ViewModelStore()
    private var scope: CoroutineScope? = null
    private var collectJob: Job? = null
    private val lastTranscript = mutableStateOf<String?>(null)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val viewModelStore: ViewModelStore get() = vmStore
    override val savedStateRegistry: SavedStateRegistry get() = savedStateController.savedStateRegistry

    override fun onCreate() {
        super.onCreate()
        savedStateController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
    }

    override fun onCreateInputView(): View {
        val app = applicationContext as NeelSpeakApplication
        val coord = app.coordinator

        scope = MainScope()
        collectJob?.cancel()
        collectJob = scope!!.launch {
            launch {
                coord.transcripts.collectLatest { text ->
                    val ic = currentInputConnection ?: return@collectLatest
                    ic.commitText(text + " ", 1)
                    lastTranscript.value = text
                }
            }
        }

        return ComposeView(this).apply {
            setViewTreeLifecycleOwner(this@NeelSpeakImeService)
            setViewTreeViewModelStoreOwner(this@NeelSpeakImeService)
            setViewTreeSavedStateRegistryOwner(this@NeelSpeakImeService)
            setContent {
                NeelSpeakImeTheme {
                    val state by coord.state.collectAsState()
                    val transcript by lastTranscript
                    NeelSpeakKeyboardSurface(
                        state = state,
                        lastTranscript = transcript,
                        onPressDown = { coord.beginDictation() },
                        onPressUp = { coord.endDictation() },
                        onSwitchKeyboard = { showKeyboardPicker() },
                        onOpenApp = { openSettingsApp() },
                    )
                }
            }
        }
    }

    override fun onStartInputView(info: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    }

    override fun onDestroy() {
        collectJob?.cancel()
        scope?.cancel()
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        super.onDestroy()
    }

    private fun showKeyboardPicker() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.showInputMethodPicker()
    }

    private fun openSettingsApp() {
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        } ?: return
        startActivity(launch)
    }

}
