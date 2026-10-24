# Changelog

## v1.0.0

### Added

- Guided four-step setup: welcome, permissions, speech model download, and a live "try it" box.
- New main window with General, AI Cleanup, Appearance, History and About sections.
- Choice of dictation key: Right Option (new default), Left Option, or either. Existing installs keep either Option.
- Cancel a dictation with Escape, and Option shortcuts (⌥←, ⌥⌘…) no longer start or paste a dictation.
- Accidental taps shorter than a quarter second are ignored.
- Live microphone level in the dictation pill, plus *Cleaning up…*, *No speech detected*, *Pasted without cleanup* and "still loading" notices.
- Persistent, searchable dictation history with copy, delete and clear; **Copy Last Dictation** in the menu bar.
- Launch at login, optional start/stop sounds, and update notifications from GitHub releases.
- AI cleanup "try it" box, and the reason a cleanup failed is now shown instead of being silently swallowed.
- Template menu bar icon that follows light/dark menu bars, turns red while recording and shows download progress.
- Standard Edit menu, so ⌘C/⌘V work in NeelSpeak's own text fields.
- `NeelSpeak --transcribe <file>` for diagnosing transcription from the command line.
- Unit tests and a CI workflow.

### Changed

- API keys and the GitHub Copilot token moved from UserDefaults to the login Keychain (migrated automatically).
- Default Anthropic model is now `claude-haiku-5-5`; requests adapt to models that reject custom `temperature` or `max_tokens`.
- FluidAudio 0.17.7.
- Redesigned app icon on the standard macOS icon grid.
- Release builds now use the macOS 26 runner so Apple Intelligence cleanup is included, and can be Developer ID signed and notarized.
- The temporary clipboard item is marked transient so clipboard managers skip it, and the clipboard is only restored if nothing else changed it.

### Fixed

- The text corrector removed the space after every full stop, question mark and colon ("Hello.How are you?") and turned the words "point", "period", "dot" and "dash" into symbols mid-sentence.
- Cleanup could stay unconnected after launch, because engine, credentials and connection were applied in an unpredictable order.

## v0.2.1

### Added

- Bundled custom app and menu bar icons for the app bundle, dashboard header, and macOS status item.
- Release packaging now copies PNG and ICNS image assets into `NeelSpeak.app`.

### Changed

- Refined the dashboard into a compact control centre with a slimmer header, cleanup settings, status sidebar, pill appearance controls, and recent dictations.
- Updated the menu bar item to show the custom icon without the text label for a cleaner macOS menu bar presence.

## v0.2.0

### Added

- Optional AI transcript cleanup with Off, Conservative, and Aggressive modes.
- Cleanup engine selection for Apple Intelligence, GitHub Copilot, OpenAI-compatible providers, and Anthropic Claude.
- GitHub Copilot OAuth device-flow sign-in, short-lived Copilot session-token refresh, and model discovery.
- OpenAI-compatible presets for GitHub Models, OpenAI, OpenRouter, Groq, Ollama, OpenCode, and custom endpoints.
- Cleanup settings persistence for engine, mode, provider URLs, model names, and API keys.
- Dashboard controls for cleanup configuration, provider credentials, Copilot sign-in, overlay themes, and transcript history.
- A dedicated `cleaning` dictation state so the app can show when cleanup is running before text is pasted.
- Release notes file used by the GitHub release workflow.

### Changed

- Replaced the Gemma/MLX cleanup dependency path with Apple Intelligence plus cloud/local OpenAI-compatible cleanup providers.
- Simplified Swift package dependencies to FluidAudio only.
- Updated release packaging to use the DMG artifact and release notes file.
- Restored release scripts to source control so tag builds can run in GitHub Actions.

### Removed

- MLX/Gemma package dependencies and model-bundling assumptions.

### Version comparison

| Area | v0.1.0 | v0.2.0 |
|------|--------|--------|
| Dictation | On-device Parakeet transcription and paste | Same core flow, plus optional cleanup before paste |
| Cleanup | Not available in the tagged release | Apple Intelligence, GitHub Copilot, OpenAI-compatible, and Anthropic engines |
| Settings | Basic setup/model flow | Full cleanup/provider configuration, persisted preferences, and transcript history |
| Packaging | ZIP/DMG release groundwork | DMG-first release notes and restored build scripts for tag releases |

## v0.1.0

- Initial public release of NeelSpeak.
- Menu-bar dictation app for macOS using NVIDIA Parakeet via FluidAudio.
- Global Option-key recording flow with automatic paste into the active app.
- Microphone and Accessibility setup flow.
