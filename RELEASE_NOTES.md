# NeelSpeak 1.0

NeelSpeak 1.0 turns the menu bar dictation tool into a finished Mac app: guided setup, a proper settings window, history, safer key handling and a long list of fixes.

## Highlights

- **New setup and settings.** A four-step setup gets you from download to your first dictation, and a new window brings together General, AI Cleanup, Appearance, History and About.
- **Choose your key.** Right Option, Left Option, or either. Escape cancels, and Option shortcuts like ⌥← no longer trigger a dictation.
- **A pill that listens back.** The dictation pill now follows your voice level and tells you when it's cleaning up, when nothing was heard, or when cleanup was skipped.
- **History.** Search and copy past dictations, or grab the latest from the menu bar.
- **Keys in the Keychain.** Cloud API keys and your Copilot sign-in move out of plain preferences into your login Keychain automatically.
- **Launch at login, sounds and update notifications.**

## Fixes

- Sentences no longer lose the space after punctuation ("Hello.How are you?"), and ordinary words like "point" and "period" are left alone.
- AI cleanup reliably connects at launch, and failures show a reason instead of silently pasting raw text.
- Anthropic cleanup defaults to `claude-haiku-5-5` and works with current Claude and OpenAI models that reject custom sampling settings.
- Apple Intelligence cleanup is included in release builds.

## Install

1. Download **NeelSpeak.dmg** below and drag NeelSpeak into Applications.
2. Open it. If macOS can't verify the developer, go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. Allow Microphone and Accessibility when asked.

Updating from 0.2.x keeps your settings. macOS may ask once to let NeelSpeak use its Keychain item.

## Requirements

- macOS 14 Sonoma or later on Apple Silicon
- Apple Intelligence cleanup needs macOS 26 with Apple Intelligence turned on
