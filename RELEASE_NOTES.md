# NeelSpeak v0.2.0

This release upgrades NeelSpeak from basic on-device dictation to configurable voice typing with optional AI transcript cleanup.

## What's new

- Optional AI cleanup removes fillers, stutters, repetitions, and course corrections before text is pasted.
- Cleanup engines now include Apple Intelligence, GitHub Copilot, OpenAI-compatible providers, and Anthropic Claude.
- GitHub Copilot sign-in uses browser-based device flow and automatically refreshes short-lived session tokens.
- OpenAI-compatible presets cover GitHub Models, OpenAI, OpenRouter, Groq, Ollama, OpenCode, and custom endpoints.
- The dashboard now includes cleanup controls, provider configuration, overlay themes, and transcript history.
- The dictation pipeline now shows a dedicated "Cleaning up" state between transcription and paste.

## Version comparison

| Area | v0.1.0 | v0.2.0 |
|------|--------|--------|
| Dictation | On-device Parakeet transcription and paste | Same core flow, plus optional cleanup before paste |
| Cleanup | Not available in the tagged release | Apple Intelligence, GitHub Copilot, OpenAI-compatible, and Anthropic engines |
| Settings | Basic setup/model flow | Full cleanup/provider configuration, persisted preferences, and transcript history |
| Packaging | ZIP/DMG release groundwork | DMG-first release notes and restored build scripts for tag releases |

## Install

1. Download **NeelSpeak.dmg** below.
2. Open the DMG and drag `NeelSpeak.app` into the **Applications** shortcut.
3. Eject the DMG.
4. First launch: Right-click `NeelSpeak.app` and choose **Open** to bypass Gatekeeper.
5. Grant **Microphone** and **Accessibility** permissions when prompted.

## Requirements

- macOS 14.0 Sonoma or later
- Apple Silicon, M1 or later
- Apple Intelligence cleanup requires macOS 26 and Apple Intelligence enabled
