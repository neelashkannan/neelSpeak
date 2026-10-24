package com.neelspeak.ime

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.MaterialTheme as M3
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.neelspeak.coordinator.DictationState

/**
 * The full IME surface. A single press-and-hold pill, a status row, a last-
 * transcript preview, and a "switch keyboard" affordance. Designed to scale
 * from 360dp budget phones to tablets/foldables — the pill is centered with a
 * max width so wider screens don't stretch the touch target ridiculously.
 *
 * Gestures: hold to record, release to insert, slide off the pill to discard.
 * While the transcript is being processed a close button cancels it.
 */
@Composable
fun NeelSpeakKeyboardSurface(
    state: DictationState,
    lastTranscript: String?,
    notice: String?,
    onPressDown: () -> Unit,
    onPressUp: () -> Unit,
    onCancel: () -> Unit,
    onTapIdleState: () -> Unit,
    onDismissNotice: () -> Unit,
    onSwitchKeyboard: () -> Unit,
) {
    val configuration = LocalConfiguration.current
    val surfaceHeight = maxOf(240, (configuration.screenHeightDp * 0.32f).toInt()).dp
    val busy = state is DictationState.Transcribing || state is DictationState.Cleaning

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(surfaceHeight),
        color = M3.colorScheme.surface,
    ) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 8.dp)) {
            val pillWidth = minOf(maxWidth.value - 32f, 320f).dp.coerceAtLeast(160.dp)

            // Switch-keyboard button top-right
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopCenter),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onSwitchKeyboard, modifier = Modifier.size(48.dp)) {
                    Icon(
                        Icons.Default.KeyboardArrowDown,
                        contentDescription = "Switch keyboard",
                        tint = M3.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Column(
                modifier = Modifier.fillMaxSize().padding(top = 8.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (notice != null) {
                    NoticeRow(notice, onDismissNotice)
                    Spacer(Modifier.height(10.dp))
                } else if (!lastTranscript.isNullOrBlank()) {
                    Text(
                        lastTranscript,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 40.dp, vertical = 4.dp),
                        style = M3.typography.bodySmall,
                        color = M3.colorScheme.onSurfaceVariant,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(10.dp))
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    MicPill(
                        state = state,
                        widthDp = if (busy) pillWidth.value - 56f else pillWidth.value,
                        onPressDown = onPressDown,
                        onPressUp = onPressUp,
                        onCancel = onCancel,
                        onTapIdleState = onTapIdleState,
                    )
                    if (busy) {
                        Spacer(Modifier.width(8.dp))
                        IconButton(onClick = onCancel, modifier = Modifier.size(48.dp)) {
                            Icon(
                                Icons.Default.Close,
                                contentDescription = "Cancel dictation",
                                tint = M3.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
                Spacer(Modifier.height(10.dp))
                Text(
                    statusLabel(state),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp)
                        .semantics { liveRegion = LiveRegionMode.Polite },
                    style = M3.typography.labelMedium,
                    color = if (state is DictationState.Error) M3.colorScheme.error else M3.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun NoticeRow(message: String, onDismiss: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(M3.colorScheme.errorContainer, RoundedCornerShape(14.dp))
            .padding(start = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Default.WarningAmber,
            contentDescription = null,
            tint = M3.colorScheme.onErrorContainer,
            modifier = Modifier.size(18.dp),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            message,
            modifier = Modifier.weight(1f).padding(vertical = 8.dp),
            style = M3.typography.bodySmall,
            color = M3.colorScheme.onErrorContainer,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        IconButton(onClick = onDismiss, modifier = Modifier.size(48.dp)) {
            Icon(
                Icons.Default.Close,
                contentDescription = "Dismiss",
                tint = M3.colorScheme.onErrorContainer,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun MicPill(
    state: DictationState,
    widthDp: Float,
    onPressDown: () -> Unit,
    onPressUp: () -> Unit,
    onCancel: () -> Unit,
    onTapIdleState: () -> Unit,
) {
    val recording = state is DictationState.Recording
    val busy = state is DictationState.Transcribing || state is DictationState.Cleaning
    val pulse = pulseAlpha(recording)
    val colors = colorsFor(state, isSystemInDarkTheme())
    val fill by animateColorAsState(colors.fill, label = "pill-fill")
    val currentState by rememberUpdatedState(state)
    val onDown by rememberUpdatedState(onPressDown)
    val onUp by rememberUpdatedState(onPressUp)
    val onCancelled by rememberUpdatedState(onCancel)
    val onStatusTap by rememberUpdatedState(onTapIdleState)
    val haptics = LocalHapticFeedback.current
    val shape = RoundedCornerShape(36.dp)
    val background = if (state is DictationState.Idle) {
        Modifier.background(Brush.linearGradient(listOf(BrandPrimary, BrandPrimaryDeep)), shape)
    } else {
        Modifier.background(fill.copy(alpha = fill.alpha * if (recording) pulse else 1f), shape)
    }

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .width(widthDp.dp)
            .heightIn(min = 72.dp)
            .then(background)
            .border(2.dp, colors.border, shape)
            .semantics {
                role = Role.Button
                contentDescription = "Voice input"
                stateDescription = accessibilityState(state)
            }
            .pointerInput(Unit) {
                detectTapGestures(
                    onTap = {
                        val s = currentState
                        if (s is DictationState.SetupRequired || s is DictationState.Error) {
                            onStatusTap()
                        }
                    },
                    onPress = {
                        val s = currentState
                        if (s is DictationState.Idle || s is DictationState.Error) {
                            onDown()
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            // false when the finger slid off the pill: discard.
                            val released = try {
                                tryAwaitRelease()
                            } catch (t: Throwable) {
                                false
                            }
                            if (released) onUp() else onCancelled()
                        }
                    },
                )
            },
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            if (busy || state is DictationState.Warming) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = colors.content,
                    strokeWidth = 2.dp,
                )
            } else {
                Icon(
                    if (state is DictationState.Error) Icons.Default.MicOff else Icons.Default.Mic,
                    contentDescription = null,
                    tint = colors.content,
                )
            }
            Spacer(Modifier.width(10.dp))
            Text(
                actionLabel(state),
                color = colors.content,
                fontWeight = FontWeight.SemiBold,
                style = M3.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun pulseAlpha(active: Boolean): Float {
    if (!active) return 1f
    val transition = rememberInfiniteTransition(label = "pulse")
    val a by transition.animateFloat(
        initialValue = 0.7f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(650), repeatMode = RepeatMode.Reverse),
        label = "pulse-a",
    )
    return a
}

// NeelSpeak brand kit — keep in sync with lib/ui/app_theme.dart::NeelSpeakBrand.
private val BrandPrimary = Color(0xFF0A5CF5)
private val BrandPrimaryDeep = Color(0xFF0036C9)
private val BrandInk = Color(0xFF0A1330)
private val RecordRed = Color(0xFFE5393B)
private val ErrorRed = Color(0xFFD93025)

private data class PillColors(val fill: Color, val border: Color, val content: Color)

private fun colorsFor(state: DictationState, dark: Boolean): PillColors = when (state) {
    is DictationState.Recording -> PillColors(RecordRed, Color(0xFFB71C1C), Color.White)
    is DictationState.Transcribing -> PillColors(BrandPrimary, BrandPrimaryDeep, Color.White)
    is DictationState.Cleaning -> PillColors(BrandPrimaryDeep, BrandPrimaryDeep, Color.White)
    is DictationState.Error -> PillColors(Color.Transparent, ErrorRed, if (dark) Color(0xFFFF8A80) else ErrorRed)
    is DictationState.DownloadingModel,
    is DictationState.Warming,
    is DictationState.SetupRequired ->
        if (dark) PillColors(Color(0xFF1B2440), Color(0xFF2C375A), Color(0xFFC9D2EE))
        else PillColors(Color(0xFFEAEEF9), Color(0xFFC8D0E6), Color(0xFF3A4566))
    is DictationState.Idle -> PillColors(BrandPrimary, BrandPrimaryDeep, Color.White)
}

private fun actionLabel(state: DictationState): String = when (state) {
    DictationState.Idle -> "Hold to speak"
    DictationState.Recording -> "Listening…"
    DictationState.Transcribing -> "Transcribing…"
    DictationState.Cleaning -> "Cleaning up…"
    DictationState.SetupRequired -> "Tap to set up"
    DictationState.Warming -> "Getting ready…"
    is DictationState.DownloadingModel -> "Downloading…"
    is DictationState.Error -> "Hold to try again"
}

private fun statusLabel(state: DictationState): String = when (state) {
    is DictationState.Error -> state.message
    DictationState.SetupRequired -> "Open NeelSpeak to download the speech model."
    is DictationState.DownloadingModel -> "Model: ${(state.progress * 100).toInt()}%"
    DictationState.Recording -> "Release to insert · slide away to cancel"
    DictationState.Transcribing, DictationState.Cleaning -> "Tap × to discard"
    else -> "Speech stays on this phone"
}

private fun accessibilityState(state: DictationState): String = when (state) {
    DictationState.Idle -> "Ready. Double-tap and hold to dictate."
    DictationState.Recording -> "Listening. Release to insert."
    DictationState.Transcribing -> "Transcribing"
    DictationState.Cleaning -> "Cleaning up"
    DictationState.SetupRequired -> "Setup needed. Double-tap to open NeelSpeak."
    DictationState.Warming -> "Getting ready"
    is DictationState.DownloadingModel -> "Downloading speech model"
    is DictationState.Error -> state.message
}

/** Follows the system light/dark setting so the keyboard matches the
 *  surrounding UI; the pill keeps the brand colours in both. */
@Composable
fun NeelSpeakImeTheme(content: @Composable () -> Unit) {
    val scheme = if (isSystemInDarkTheme()) {
        darkColorScheme(
            primary = Color(0xFF8AB0FF),
            surface = Color(0xFF0E1426),
            onSurface = Color(0xFFF1F4FF),
            onSurfaceVariant = Color(0xFFAEB8D6),
            error = Color(0xFFFF8A80),
            errorContainer = Color(0xFF4A1C1C),
            onErrorContainer = Color(0xFFFFDAD6),
        )
    } else {
        lightColorScheme(
            primary = BrandPrimary,
            surface = Color(0xFFF4F6FC),
            onSurface = BrandInk,
            onSurfaceVariant = Color(0xFF4A5576),
            error = ErrorRed,
        )
    }
    MaterialTheme(colorScheme = scheme, content = content)
}
