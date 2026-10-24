package com.neelspeak.ime

import android.content.Context
import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.neelspeak.app.NeelSpeakApplication
import com.neelspeak.coordinator.DictationCoordinator
import com.neelspeak.coordinator.DictationState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The Android IME. Renders the Compose press-and-hold mic pill inside a
 * LifecycleWrapper that — on attachment — walks up to the IME window root
 * and stamps the ViewTree owners there, which is where Compose actually
 * looks for them (not on the ComposeView itself).
 */
class NeelSpeakImeService : InputMethodService(),
    LifecycleOwner,
    ViewModelStoreOwner,
    SavedStateRegistryOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this)
    private val vmStore = ViewModelStore()
    private var scope: CoroutineScope? = null
    private val lastTranscript = mutableStateOf<String?>(null)

    private val coordinator: DictationCoordinator
        get() = (applicationContext as NeelSpeakApplication).coordinator

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val viewModelStore: ViewModelStore get() = vmStore
    override val savedStateRegistry: SavedStateRegistry get() = savedStateController.savedStateRegistry

    override fun onCreate() {
        super.onCreate()
        savedStateController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        // Collected once per service, not per input view: onCreateInputView
        // runs again on rotation/theme changes and would commit twice.
        scope = MainScope().also { s ->
            s.launch {
                coordinator.results.collect { result ->
                    if (result.origin != DictationCoordinator.Origin.Keyboard) return@collect
                    if (result.text.isBlank()) return@collect
                    commit(result.text)
                    lastTranscript.value = result.text
                }
            }
        }
    }

    /** Inserts [text], adding a separating space only when the cursor sits
     *  right after a non-space character. */
    private fun commit(text: String) {
        val ic = currentInputConnection ?: return
        val before = ic.getTextBeforeCursor(1, 0)
        val needsSpace = !before.isNullOrEmpty() && !before.last().isWhitespace()
        ic.commitText((if (needsSpace) " " else "") + text, 1)
    }

    override fun onCreateInputView(): View {
        val coord = coordinator

        val composeView = ComposeView(this).apply {
            setContent {
                NeelSpeakImeTheme {
                    val state by coord.state.collectAsState()
                    val notice by coord.notice.collectAsState()
                    val transcript by lastTranscript
                    NeelSpeakKeyboardSurface(
                        state = state,
                        lastTranscript = transcript,
                        notice = notice,
                        onPressDown = { coord.beginDictation() },
                        onPressUp = { coord.endDictation() },
                        onCancel = { coord.cancelDictation() },
                        onTapIdleState = { handleStatusTap(coord) },
                        onDismissNotice = { coord.dismissNotice() },
                        onSwitchKeyboard = { showKeyboardPicker() },
                    )
                }
            }
        }

        // Walk up to the window root on attachment and stamp the ViewTree owners
        // there — that's where Compose's WindowRecomposer looks for them.
        return object : FrameLayout(this) {
            override fun onAttachedToWindow() {
                super.onAttachedToWindow()
                var root: View = this
                while (root.parent is View) root = root.parent as View
                root.setViewTreeLifecycleOwner(this@NeelSpeakImeService)
                root.setViewTreeViewModelStoreOwner(this@NeelSpeakImeService)
                root.setViewTreeSavedStateRegistryOwner(this@NeelSpeakImeService)
            }
        }.also { it.addView(composeView) }
    }

    /** Tap on the pill while it can't record: open the app when setup is
     *  missing, otherwise clear the error so the next hold works. */
    private fun handleStatusTap(coord: DictationCoordinator) {
        if (coord.needsApp) {
            openSettingsApp()
        } else if (coord.state.value is DictationState.Error) {
            coord.clearError()
        }
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        // Keyboard hidden or the field went away mid-hold: release the mic
        // and drop the recording instead of typing into whatever comes next.
        if (coordinator.state.value is DictationState.Recording) coordinator.cancelDictation()
        super.onFinishInputView(finishingInput)
    }

    override fun onDestroy() {
        if (coordinator.state.value is DictationState.Recording) coordinator.cancelDictation()
        scope?.cancel()
        scope = null
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        vmStore.clear()
        super.onDestroy()
    }

    private fun showKeyboardPicker() {
        (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager).showInputMethodPicker()
    }

    private fun openSettingsApp() {
        packageManager.getLaunchIntentForPackage(packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ?.let { startActivity(it) }
    }
}
