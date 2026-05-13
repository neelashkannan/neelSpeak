# Changelog

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
