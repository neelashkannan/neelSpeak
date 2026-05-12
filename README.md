# NeelSpeak

> A free, open-source, fully local voice-to-text dictation app for macOS — a privacy-first alternative to **Whispr Flow** and **Super Whispr**.

[![Latest Release](https://img.shields.io/github/v/release/mrmachineroboboy/neelSpeak?label=Download&style=for-the-badge)](https://github.com/mrmachineroboboy/neelSpeak/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue?style=for-the-badge&logo=apple)](https://github.com/mrmachineroboboy/neelSpeak/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

## What is NeelSpeak?

NeelSpeak is a lightweight macOS menubar app that lets you dictate text into **any application** using a global hotkey. It transcribes your voice completely **on-device** using Apple Silicon — no internet, no subscriptions, no data leaving your Mac.

If you've used Whispr Flow or Super Whispr and want a free, open-source alternative that works 100% offline, NeelSpeak is for you.

---

## Features

- 🎙️ **Hold Right Option** to dictate — release to paste
- 🤖 **On-device AI** via [WhisperKit](https://github.com/argmaxinc/WhisperKit) & [FluidAudio](https://github.com/FluidInference/FluidAudio)
- 🔒 **100% private** — no internet connection required
- ⚡ **Apple Silicon native** (arm64)
- 🖥️ **Menu bar app** — lives quietly in your status bar
- 🎨 **Listening overlay** with customisable themes
- 📋 **Transcript history** in the dashboard window
- 🆓 **Free and open-source**

---

## Download

Head to the [**Releases page**](https://github.com/mrmachineroboboy/neelSpeak/releases) to download the latest `.app`.

1. Download `NeelSpeak.zip` from the latest release
2. Unzip and move `NeelSpeak.app` to your `/Applications` folder
3. Right-click → Open (first launch only, to bypass Gatekeeper)
4. Grant **Microphone** and **Accessibility** permissions when prompted

---

## Requirements

| Requirement | Minimum |
|-------------|---------|
| macOS       | 14.0 (Sonoma) |
| Architecture | Apple Silicon (M1 or later) |

---

## Build from Source

```bash
git clone https://github.com/mrmachineroboboy/neelSpeak.git
cd neelSpeak
bash Scripts/build-app.sh
open NeelSpeak.app
```

> Requires Xcode Command Line Tools: `xcode-select --install`

---

## Usage

1. Launch NeelSpeak from your Applications folder or from the built `.app`
2. Complete the one-time setup (grant microphone + accessibility permissions, choose a Whisper model)
3. Click anywhere you want to type
4. **Hold Right Option** → speak → **release** to paste the transcription

---

## vs. Whispr Flow / Super Whispr

| Feature | NeelSpeak | Whispr Flow | Super Whispr |
|---------|-----------|-------------|--------------|
| Price | Free | Paid | Paid |
| Open Source | ✅ | ❌ | ❌ |
| 100% Offline | ✅ | Optional | Optional |
| macOS | ✅ | ✅ | ✅ |
| Subscription | None | Required | Required |
| Local AI model | WhisperKit / FluidAudio | Varies | Varies |

---

## Contributing

Pull requests and issues are welcome! Please open an issue first to discuss larger changes.

---

## License

MIT — see [LICENSE](LICENSE).
