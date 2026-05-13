# NeelSpeak — Claude Code Guide

## What this is
NeelSpeak is a macOS menu-bar voice-typing app. Hold **Option** anywhere to dictate; it transcribes via NVIDIA Parakeet (FluidAudio, on-device) and types into the active app via simulated Cmd+V. An optional local-AI cleanup stage strips fillers, stutters, and course corrections.

## ⚠️ Build requirements

**Full Xcode is required** (not just Command Line Tools) because the Gemma cleanup engine depends on `mlx-swift`, whose Metal shaders only compile under `xcodebuild`. Without Xcode:
- `swift build` produces a binary that loads, but the moment any MLX code is called the process aborts with `Failed to load the default metallib` (uncatchable C++ exception).
- The Apple Foundation Models cleanup engine still works without Xcode.

Verify Xcode is set up correctly:
```bash
xcode-select -p              # must end with /Xcode.app/Contents/Developer
xcrun --find metal           # must print a path
xcrun --find metallib        # must print a path
```
If `xcode-select -p` shows `/Library/Developer/CommandLineTools`, run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` after installing Xcode.

`Scripts/build-app.sh` auto-detects Xcode: it uses `xcodebuild` when available (Gemma works) and falls back to `swift build` with a warning otherwise (Gemma will crash).

## Key commands

### Build & run
```bash
# Quick syntax check (won't ship Metal shaders even with Xcode)
swift build

# Full redeploy — kills, wipes prefs/permissions, builds release, installs, launches
bash Scripts/redeploy-app.sh

# Soft reinstall — preserves prefs/permissions (use after minor code changes)
pkill -x NeelSpeak || true
bash Scripts/build-app.sh
rm -rf /Applications/NeelSpeak.app
cp -R NeelSpeak.app /Applications/
xattr -dr com.apple.quarantine /Applications/NeelSpeak.app
open /Applications/NeelSpeak.app

# Watch runtime logs (cleanup, download, latency)
log stream --predicate 'subsystem == "com.neelspeak.app"' --info

# Run from terminal with stdout/stderr visible (debugging crashes)
/Applications/NeelSpeak.app/Contents/MacOS/NeelSpeak
```

### When to use full vs soft redeploy
- **Full redeploy** (`redeploy-app.sh`): after changing entitlements, Info.plist, bundle ID, or when debugging permission issues. Resets Accessibility/Microphone grants — user must re-approve.
- **Soft reinstall**: after any Swift code change. Preserves all user prefs (cleanup mode, engine selection, model downloads, theme).

## Architecture

```
main.swift
└── AppDelegate           ← wires everything together, holds all top-level objects
    ├── DictationCoordinator   ← state machine: setupRequired→idle→recording→transcribing→cleaning→idle
    │   ├── AudioEngine        ← CoreAudio mic capture
    │   ├── HotkeyManager      ← global Option-key listener (CGEventTap)
    │   ├── WhisperService     ← actor: FluidAudio Parakeet STT (WhisperKit path is stubbed out)
    │   ├── TranscriptCorrector ← pure regex: whitespace, spoken punctuation, brand names, domains
    │   └── LLMTranscriptCleaner ← actor: Apple Intelligence or Gemma 3 4B MLX
    ├── VoiceTyperViewModel    ← @MainActor ObservableObject; all published state for SwiftUI
    ├── VoiceTyperDashboard    ← SwiftUI main window (setup flow + control centre)
    ├── ListeningOverlayController ← floating pill (records → transcribing → cleaning)
    ├── StatusBarController    ← menu-bar item
    └── TextInjector           ← pastes text via CGEvent Cmd+V simulation
```

## Pipeline (per dictation)
1. `AudioEngine` captures PCM samples
2. `WhisperService.transcribe()` → raw transcript string
3. `TranscriptCorrector.correct()` → normalises punctuation, brand names
4. If cleanup enabled: `LLMTranscriptCleaner.clean()` → removes fillers/stutters/repetitions
5. `TextInjector.inject()` → pastes into active app

## Cleanup feature

### Engines
| Engine | Availability | Download |
|--------|-------------|---------|
| Apple Intelligence (default) | macOS 26+, Apple Intelligence enabled | None — on-device model built into OS |
| Gemma 3 1B (4-bit MLX) | macOS 14+, Apple Silicon | ~720 MB, stored in `~/Library/Application Support/NeelSpeak/Models/MLX/` |

**Note:** Gemma 3 1B is used (not 4B) because the 4B variant on `mlx-community/gemma-3-4b-it-4bit` is the multimodal (vision + text) build, and mlx-swift-examples 2.29.1's text-only loader rejects it with a `mismatchedSize` on `embed_tokens.weight`. The 1B model is text-only and loads cleanly; it is also faster and lighter, which suits the filler-removal use case.

### Modes
- **Off** — passthrough, no LLM called
- **Conservative** — removes fillers (um/uh/like), stutters, exact repetitions, course corrections only
- **Aggressive** — all of conservative + tightens run-on sentences, fixes spoken-word grammar slips

### Key files
- `Pipeline/CleanupMode.swift` — `CleanupEngine` and `CleanupMode` enums with system prompts
- `Pipeline/LLMTranscriptCleaner.swift` — actor, lazy model load, error fallback
- `App/VoiceTyperViewModel.swift` — `cleanupMode` and `cleanupEngine` @Published, persisted to UserDefaults

## STT models
Only Parakeet is active. WhisperKit was removed due to a `swift-transformers` version conflict with `mlx-swift-examples`.

| Model | Runtime | Location |
|-------|---------|---------|
| NVIDIA Parakeet TDT v3 | FluidAudio | `~/Library/Application Support/NeelSpeak/Models/FluidAudio/parakeet-tdt-0.6b-v3/` |
| Gemma 3 1B-it 4-bit | MLX (mlx-swift-examples 2.29.1) | `~/Library/Application Support/NeelSpeak/Models/MLX/models/mlx-community/gemma-3-1b-it-4bit/` |

## Dependencies
```
FluidAudio          0.14.4   — Parakeet STT
mlx-swift-examples  2.29.1   — MLXLLM / MLXLMCommon for Gemma inference
└── mlx-swift       0.29.1
└── swift-transformers 1.0.0
```
WhisperKit is intentionally absent — adding it back causes a `swift-transformers` version conflict.

## UserDefaults keys (bundle ID: com.neelspeak.app)
| Key | Type | Default |
|-----|------|---------|
| `selectedModelID` | String | `nvidia-parakeet-v3` |
| `setupComplete` | Bool | false |
| `cleanupMode` | String (CleanupMode.rawValue) | `off` |
| `cleanupEngine` | String (CleanupEngine.rawValue) | `foundationModels` |
| `overlayThemeID` | String | first theme |

## Important notes
- App requires **Accessibility** permission to receive the global Option hotkey and to simulate Cmd+V.
- App requires **Microphone** permission for audio capture.
- `tccutil reset` in the redeploy script clears these — user re-approves on next launch.
- The cleanup LLM runs **after** transcription and adds 0.5–3 s latency depending on engine/mode. The pill overlay and status bar show "Cleaning up…" during this.
- `log stream --predicate 'subsystem == "com.neelspeak.app"' --info` shows live cleanup timing and any errors.
