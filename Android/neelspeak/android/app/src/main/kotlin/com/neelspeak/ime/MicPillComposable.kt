package com.neelspeak.ime

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.MaterialTheme as M3
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Mic
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.neelspeak.coordinator.DictationState

/**
 * The full IME surface. A single press-and-hold pill, a status row, a last-
 * transcript preview, and a "switch keyboard" affordance. Designed to scale
 * from 360dp budget phones to tablets/foldables — the pill is centered with a
 * max width so wider screens don't stretch the touch target ridiculously.
 */
@Composable
fun NeelSpeakKeyboardSurface(
    state: DictationState,
    lastTranscript: String?,
    onPressDown: () -> Unit,
    onPressUp: () -> Unit,
    onSwitchKeyboard: () -> Unit,
    onOpenApp: () -> Unit,
) {
    val configuration = LocalConfiguration.current
    val surfaceHeight = maxOf(240, (configuration.screenHeightDp * 0.32f).toInt()).dp

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(surfaceHeight),
        color = M3.colorScheme.surface,
    ) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp)) {
            val pillWidth = minOf(maxWidth.value - 32f, 320f).dp.coerceAtLeast(160.dp)

            // Switch-keyboard chip top-right
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopCenter),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onSwitchKeyboard, modifier = Modifier.size(40.dp)) {
                    Icon(Icons.Default.KeyboardArrowDown, contentDescription = "Switch keyboard")
                }
            }

            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (!lastTranscript.isNullOrBlank()) {
                    Text(
                        lastTranscript,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 24.dp, vertical = 4.dp)
                            .alpha(0.7f),
                        style = M3.typography.bodySmall,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(12.dp))
                }
                MicPill(
                    state = state,
                    widthDp = pillWidth.value,
                    onPressDown = onPressDown,
                    onPressUp = onPressUp,
                    onTapWhenSetupNeeded = onOpenApp,
                )
                Spacer(Modifier.height(10.dp))
                Text(
                    statusLabel(state),
                    style = M3.typography.labelMedium,
                    color = M3.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun MicPill(
    state: DictationState,
    widthDp: Float,
    onPressDown: () -> Unit,
    onPressUp: () -> Unit,
    onTapWhenSetupNeeded: () -> Unit,
) {
    val pulse = pulseAlpha(state is DictationState.Recording)
    val (bg, border, fg) = colorsFor(state)
    val pressGate = state is DictationState.Idle
    val setupGate = state is DictationState.SetupRequired

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .width(widthDp.dp)
            .height(72.dp)
            .background(bg.copy(alpha = if (state is DictationState.Recording) pulse else 1f), RoundedCornerShape(36.dp))
            .border(2.dp, border, RoundedCornerShape(36.dp))
            .pointerInput(pressGate, setupGate) {
                if (setupGate) {
                    detectTapGestures(onTap = { onTapWhenSetupNeeded() })
                } else if (pressGate) {
                    detectTapGestures(onPress = {
                        onPressDown()
                        try { awaitRelease() } finally { onPressUp() }
                    })
                }
            },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
            Icon(Icons.Default.Mic, contentDescription = null, tint = fg)
            Spacer(Modifier.width(8.dp))
            Text(actionLabel(state), color = fg, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
    }
}

@Composable
private fun pulseAlpha(active: Boolean): Float {
    if (!active) return 1f
    val transition = rememberInfiniteTransition(label = "pulse")
    val a by transition.animateFloat(
        initialValue = 0.55f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(600), repeatMode = RepeatMode.Reverse),
        label = "pulse-a",
    )
    return a
}

private fun colorsFor(state: DictationState): Triple<Color, Color, Color> = when (state) {
    is DictationState.Recording -> Triple(Color(0xFFE53935), Color(0xFFB71C1C), Color.White)
    is DictationState.Transcribing -> Triple(Color(0xFFFFA000), Color(0xFFEF6C00), Color.White)
    is DictationState.Cleaning -> Triple(Color(0xFF3366FF), Color(0xFF1A237E), Color.White)
    is DictationState.Error -> Triple(Color.Transparent, Color(0xFFE53935), Color(0xFFE53935))
    is DictationState.DownloadingModel,
    is DictationState.Warming,
    is DictationState.SetupRequired -> Triple(Color(0xFFE0E0E0), Color(0xFFBDBDBD), Color(0xFF424242))
    is DictationState.Idle -> Triple(Color(0xFF222222), Color(0xFF222222), Color.White)
}

private fun actionLabel(state: DictationState): String = when (state) {
    DictationState.Idle -> "Hold to speak"
    DictationState.Recording -> "Listening…"
    DictationState.Transcribing -> "Transcribing…"
    DictationState.Cleaning -> "Cleaning…"
    DictationState.SetupRequired -> "Tap to set up"
    DictationState.Warming -> "Warming up…"
    is DictationState.DownloadingModel -> "Downloading…"
    is DictationState.Error -> "Tap to retry"
}

private fun statusLabel(state: DictationState): String = when (state) {
    is DictationState.Error -> state.message
    DictationState.SetupRequired -> "Open NeelSpeak to download the speech model."
    is DictationState.DownloadingModel -> "Model: ${(state.progress * 100).toInt()}%"
    else -> "NeelSpeak — voice keyboard"
}

/** Force the IME surface to ALWAYS use light scheme for consistency with the
 *  system keyboard look. Apps with dark themes still get the same pill. */
@Composable
fun NeelSpeakImeTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = lightColorScheme(), content = content)
}
