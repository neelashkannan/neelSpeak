# NeelSpeak

> Free, open-source voice typing for macOS. Hold a key, speak, let go — your words appear wherever you're typing. Transcription runs on your Mac; AI cleanup is optional.

[![Latest Release](https://img.shields.io/github/v/release/neelashkannan/neelSpeak?label=Download&style=for-the-badge)](https://github.com/neelashkannan/neelSpeak/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue?style=for-the-badge&logo=apple)](https://github.com/neelashkannan/neelSpeak/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

**Current release:** `v1.0.0`

---

## What it does

NeelSpeak lives in your menu bar. Hold **Right Option** (configurable) in any app, speak, and let go: the text is transcribed on-device by [NVIDIA Parakeet](https://github.com/FluidInference/FluidAudio) and pasted at your cursor. Your clipboard is restored afterwards.

An optional AI cleanup pass removes "um", "uh", stutters and false starts before the text lands. Use Apple Intelligence to keep everything on your Mac, or a cloud provider for speed.

## Features

- **Hold to talk, anywhere** — Right Option, Left Option, or either. Press Escape or any other key while holding to cancel, so Option shortcuts keep working.
- **On-device speech recognition** — NVIDIA Parakeet TDT v3 (25 European languages) on the Apple Neural Engine.
- **Live dictation pill** — shows your voice level while you speak, then *Transcribing…* and *Cleaning up…*, and tells you when nothing was heard.
- **Optional AI cleanup** — Apple Intelligence, GitHub Copilot, any OpenAI-compatible API, or Anthropic Claude, with a built-in "try it" box.
- **Smart formatting** — spoken addresses and symbols ("google dot com", "john at sign gmail dot com", "comma", "question mark") without mangling ordinary sentences.
- **History** — searchable list of past dictations with one-click copy, kept only on your Mac (or turned off).
- **Polished Mac app** — guided setup, launch at login, optional start/stop sounds, update notifications, light and dark mode.
- **Private by design** — API keys live in your Keychain; nothing leaves your Mac unless you pick a cloud cleanup engine.

## Install

1. Download **NeelSpeak.dmg** from the [latest release](https://github.com/neelashkannan/neelSpeak/releases/latest).
2. Open it and drag **NeelSpeak** into **Applications**.
3. Open NeelSpeak. If macOS says it can't verify the developer, open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** (only needed once for builds that aren't notarized).
4. Follow the setup: allow **Microphone** and **Accessibility**, download the speech model (about 460 MB, once), and try a dictation.

### Requirements

| | Minimum |
|---|---|
| macOS | 14 Sonoma |
| Mac | Apple Silicon (M1 or later) |
| Apple Intelligence cleanup | macOS 26 with Apple Intelligence turned on |

## Using NeelSpeak

1. Click where you want to type.
2. Hold **Right Option**, speak, and let go.
3. The text is pasted. Missed it? Choose **Copy Last Dictation** from the menu bar.

Open the menu bar icon for settings, history, launch at login and updates.

### AI cleanup

| Engine | Where it runs | Notes |
|--------|---------------|-------|
| **Apple Intelligence** | On your Mac | macOS 26+. No account needed. |
| **GitHub Copilot** | GitHub | Sign in with your Copilot subscription; pick any chat model it offers. |
| **OpenAI-compatible** | Your provider | Presets for GitHub Models, OpenAI, OpenRouter, Groq, Ollama (local) and OpenCode (local). |
| **Anthropic Claude** | Anthropic | Default model `claude-haiku-5-5`. |

| Mode | What it does |
|------|-------------|
| **Off** | Paste exactly what was said. |
| **Conservative** | Remove fillers, stutters, repetitions and course corrections. |
| **Aggressive** | Also tighten run-on sentences and fix spoken-grammar slips. |

If a cleanup engine fails (bad key, no network), NeelSpeak pastes your words as transcribed and shows why in the pill and in **AI Cleanup**.

## Privacy

- Speech is recorded only while you hold the dictation key and is transcribed on your Mac.
- With a cloud cleanup engine, the transcript text (never audio) is sent to that provider.
- API keys and the Copilot sign-in token are stored in your login Keychain.
- History is stored in `~/Library/Application Support/NeelSpeak/History.json`, readable only by you. Turn it off or clear it in **History**.
- The update check contacts the GitHub releases API and sends nothing about you.

## Build from source

Xcode 26 or later is recommended (it includes the Apple Intelligence SDK). Command Line Tools also work, without Apple Intelligence cleanup.

```bash
git clone https://github.com/neelashkannan/neelSpeak.git
cd neelSpeak
bash Scripts/setup-codesign.sh   # once: stable local signing so permissions survive rebuilds
bash Scripts/build-app.sh
open NeelSpeak.app
```

Run the tests with `swift test`. To try the pipeline on an audio file without the hotkey:

```bash
NeelSpeak.app/Contents/MacOS/NeelSpeak --transcribe recording.m4a --cleanup conservative
```

### Releasing

Push a `v*` tag. The release workflow runs the tests, builds the app, packages `NeelSpeak.dmg` with a SHA-256 checksum and publishes it with `RELEASE_NOTES.md`. If these repository secrets are set, it also signs with Developer ID and notarizes:

`MACOS_CERTIFICATE_P12` (base64), `MACOS_CERTIFICATE_PASSWORD`, `MACOS_SIGNING_IDENTITY`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`.

## Contributing

Issues and pull requests are welcome. Please open an issue first for larger changes.

## License

MIT — see [LICENSE](LICENSE).
