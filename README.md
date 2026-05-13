# NeelSpeak

> A free, open-source voice-to-text dictation app for macOS — with on-device transcription and optional AI cleanup via Apple Intelligence, GitHub Copilot, Ollama, and more.

[![Latest Release](https://img.shields.io/github/v/release/neelashkannan/neelSpeak?label=Download&style=for-the-badge)](https://github.com/neelashkannan/neelSpeak/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue?style=for-the-badge&logo=apple)](https://github.com/neelashkannan/neelSpeak/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

## What is NeelSpeak?

NeelSpeak is a lightweight macOS menu-bar app that lets you dictate text into **any application** using a global hotkey. Hold **Right Option**, speak, and release — your words are transcribed on-device via [NVIDIA Parakeet](https://github.com/FluidInference/FluidAudio) and pasted wherever your cursor is.

Optionally, an AI cleanup stage removes fillers, stutters, and course corrections before the text lands. You choose the engine: fully on-device Apple Intelligence, your existing GitHub Copilot subscription, a local Ollama server, or any OpenAI-compatible/Anthropic API.

**Current release:** `v0.2.1`

---

## Features

- 🎙️ **Hold Right Option** to dictate — release to paste
- 🤖 **On-device STT** via [FluidAudio](https://github.com/FluidInference/FluidAudio) (NVIDIA Parakeet TDT v3)
- ✨ **AI transcript cleanup** — removes fillers, stutters, and course corrections
- ⚡ **Apple Silicon native** (arm64)
- 🖥️ **Menu bar app** — lives quietly in your status bar
- 🧭 **Custom app + menu bar icons** for a more polished macOS presence
- 🎨 **Listening overlay** with customisable themes
- 🧩 **Compact control centre** for cleanup, status, appearance, and recent dictations
- 📋 **Transcript history** in the dashboard window
- 🆓 **Free and open-source**

---

## Transcript Cleanup Engines

Cleanup is optional. When enabled, a lightweight LLM pass removes _"um"_, _"uh"_, stutters, repetitions, and course corrections before the text is pasted. Four engines are supported:

| Engine | Availability | Latency | Data leaves your Mac? |
|--------|-------------|---------|----------------------|
| **Apple Intelligence** | macOS 26+, Apple Intelligence enabled | ~1–2 s | ❌ Never |
| **GitHub Copilot** | Active Copilot subscription, OAuth sign-in | ~300 ms | ✅ Sent to GitHub |
| **OpenAI-compatible** | API key or local server | ~300 ms | Depends on provider |
| **Anthropic Claude** | Anthropic API key | ~250 ms | ✅ Sent to Anthropic |

### OpenAI-compatible presets

The OpenAI-compatible engine ships with one-click presets for common providers:

| Preset | Notes |
|--------|-------|
| **GitHub Models** (default) | Free tier, GitHub PAT (no scopes needed) |
| **OpenAI** | `sk-...` key from platform.openai.com |
| **OpenRouter** | Access hundreds of models with one key |
| **Groq** | Very fast inference, `gsk_...` key |
| **Ollama** | Fully local — `http://localhost:11434/v1`, no API key needed |
| **OpenCode** | Local OpenCode server (`opencode serve`) |
| **Custom** | Any OpenAI-compatible base URL |

### Cleanup modes

| Mode | What it does |
|------|-------------|
| **Off** | Paste the raw transcript exactly as spoken |
| **Conservative** | Remove fillers, stutters, repetitions, and course corrections only |
| **Aggressive** | All of the above, plus tighten run-on sentences and fix spoken-word grammar |

---

## Download

Head to the [**Releases page**](https://github.com/neelashkannan/neelSpeak/releases) to download the latest `.dmg`.

1. Download `NeelSpeak.dmg` from the latest release
2. Open the DMG and drag `NeelSpeak.app` into the **Applications** shortcut
3. Eject the DMG
4. Right-click → Open (first launch only, to bypass Gatekeeper)
5. Grant **Microphone** and **Accessibility** permissions when prompted

---

## Requirements

| Requirement | Minimum |
|-------------|---------|
| macOS | 14.0 (Sonoma) |
| Architecture | Apple Silicon (M1 or later) |
| Apple Intelligence cleanup | macOS 26 + Apple Intelligence enabled |

---

## Build from Source

> **Full Xcode is required** (not just Command Line Tools) — install from the Mac App Store, then:
>
> ```bash
> sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
> ```

```bash
git clone https://github.com/neelashkannan/neelSpeak.git
cd neelSpeak
bash Scripts/build-app.sh
open NeelSpeak.app
```

For a full reinstall that resets permissions:

```bash
bash Scripts/redeploy-app.sh
```

---

## Usage

1. Launch NeelSpeak from your Applications folder
2. Complete the one-time setup (grant Microphone + Accessibility permissions, download the Parakeet model)
3. Click anywhere you want to type
4. **Hold Right Option** → speak → **release** to paste the transcription
5. *(Optional)* Open the dashboard to configure cleanup engine and mode

---

## GitHub Copilot Setup

1. In the NeelSpeak dashboard, go to **Cleanup → Engine → GitHub Copilot**
2. Click **Sign in to GitHub Copilot** — a browser window opens automatically
3. Enter the displayed user code and authorise the app
4. NeelSpeak stores the OAuth token locally; no further sign-in needed

The session token auto-refreshes (~30 min expiry). You can also pick from the list of models your Copilot subscription provides.

---

## Contributing

Pull requests and issues are welcome! Please open an issue first to discuss larger changes.

---

## License

MIT — see [LICENSE](LICENSE).
