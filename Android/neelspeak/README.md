# NeelSpeak Android

Voice-typing keyboard for Android. Hold the mic button in any text field to
dictate — release to insert the transcript, slide off the button to cancel.
Architecture mirrors the macOS app under `../../Sources/VoiceTyper/`:

```
mic capture (AudioRecord 16 kHz mono) →
  sherpa-onnx Parakeet TDT (on-device) →
    TranscriptCorrector (regex) →
      LlmTranscriptCleaner (optional: OpenAI-compatible / Anthropic / GitHub Copilot / on-device Gemma) →
        InputConnection.commitText
```

The IME is native Kotlin (Compose). The settings/onboarding shell is Flutter.
Both run in the same process and share two `SharedPreferences` files —
settings changes from the settings UI take effect in the IME instantly.

## Layout

```
lib/                                  Flutter — settings & onboarding
  main.dart                           ProviderScope + route gate
  pages/home_page.dart                Status, setup checklist, last cleanup error, settings
  pages/onboarding/*.dart             Welcome → mic → model download → test → enable IME → select IME → engine
  pages/settings/*.dart               Engine config + test cleanup
  state/settings_provider.dart        Riverpod bridge to platform channels
  platform/channels.dart              Dart facades for the MethodChannels
  ui/app_theme.dart, premium_widgets.dart  Design tokens (brand colours, spacing) and shared widgets
android/app/src/main/kotlin/com/neelspeak/
  ime/NeelSpeakImeService.kt          InputMethodService — hosts the Compose pill
  ime/MicPillComposable.kt            Press-and-hold pill (idle / recording / transcribing / cleaning / error)
  audio/AudioCapture.kt               AudioRecord at 16 kHz mono PCM16
  stt/ParakeetSherpaEngine.kt         sherpa-onnx OfflineRecognizer wrapper (Parakeet TDT)
  stt/ModelDownloader.kt              Resumable HTTPS download + staged tar.bz2 extraction
  cleanup/CleanupMode.kt              Port of CleanupMode.swift (prompts, few-shot examples, presets)
  cleanup/TranscriptCorrector.kt      Port of TranscriptCorrector.swift
  cleanup/{OpenAi,Anthropic,Copilot}CleanupClient.kt, CloudHttp.kt   HTTP clients
  cleanup/CopilotAuthService.kt       GitHub Copilot OAuth device flow
  cleanup/OnDeviceLlmClient.kt        MediaPipe LLM Inference (Gemma 3 1B int4)
  coordinator/DictationCoordinator.kt State machine: idle → recording → transcribing → cleaning → idle
  prefs/{Settings,SecureStore}.kt     SharedPreferences + EncryptedSharedPreferences
  bridge/*.kt                         MethodChannel handlers
android/app/src/test/kotlin/          JVM unit tests (corrector, cloud request shapes)
```

## Build

Requirements: a current stable Flutter (tested with 3.47.6), JDK 17, Android SDK with
platform 36 and build-tools 35. The Android Gradle build uses Gradle 8.14.3,
AGP 8.13 and Kotlin 2.2.20 — the oldest versions current Flutter accepts.
The first build downloads NDK 28.2 (needed to package the native libraries).

```bash
cd Android/neelspeak

# 1. Pull Dart dependencies.
flutter pub get

# 2. Drop the sherpa-onnx Android AAR into android/app/libs/ (git-ignored).
#    Download sherpa-onnx-X.Y.Z.aar from
#    https://github.com/k2-fsa/sherpa-onnx/releases (1.13.0 is known to work).
mkdir -p android/app/libs

# 3. Run on a device or emulator.
flutter run
```

Checks:

```bash
flutter analyze
flutter test                                   # widget tests, incl. 200 % text in light/dark
(cd android && ./gradlew :app:testDebugUnitTest)   # Kotlin unit tests
flutter build apk --debug
flutter build apk --release
```

### Release signing

Release builds sign with the key described in `android/key.properties`
(git-ignored — never commit it or the keystore):

```properties
storeFile=/absolute/path/to/neelspeak-release.jks
storePassword=…
keyAlias=neelspeak
keyPassword=…
```

Create the keystore once, outside the repo:

```bash
keytool -genkeypair -v -keystore ~/keys/neelspeak-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias neelspeak
```

**Without `key.properties`, release builds fall back to the debug key** so
`flutter build apk --release` still works locally. Such APKs are fine for
side-loading on your own devices but can't be uploaded to Google Play and
won't install over a build signed with the real key (or vice versa).

R8 / code shrinking is **off** for release builds: sherpa-onnx and MediaPipe
reach their Kotlin/Java classes from native code, and the on-device LLM
client loads MediaPipe through reflection. Enable it only together with keep
rules that have been verified on a device.

The version comes from `pubspec.yaml` (`version: 1.0.0+2` → versionName
1.0.0, versionCode 2). Bump the number after `+` for every upload.

## Model setup (first run)

The keyboard needs the Parakeet TDT 0.6B INT8 model: a ~460 MB download that
unpacks to ~630 MB (so ~1.1 GB free space is needed during setup).
Onboarding and the Home checklist download it; an interrupted download
resumes from where it stopped. Files land in:

```
/data/data/com.neelspeak/files/models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8/
  encoder.int8.onnx  decoder.int8.onnx  joiner.int8.onnx  tokens.txt
```

The archive is unpacked into a `.partial` folder and moved into place only
when complete, and each file's size is checked before the model counts as
installed — a half-finished download is never treated as ready.

For the optional on-device cleanup engine (Gemma 3 1B int4, ~530 MB), the
`.task` file goes at:

```
/data/data/com.neelspeak/files/models/llm/gemma-3-1b-it-int4.task
```

You can `adb push` these into place during development:

```bash
adb push gemma-3-1b-it-int4.task /sdcard/Download/
adb shell run-as com.neelspeak cp /sdcard/Download/gemma-3-1b-it-int4.task files/models/llm/
```

## Using the keyboard

1. Open NeelSpeak and follow onboarding (microphone, model, test, keyboard).
2. **Settings → System → Keyboard → On-screen keyboard → Manage keyboards** →
   turn on **NeelSpeak** (onboarding opens this screen).
3. In any text field, switch to NeelSpeak with the keyboard switcher.
4. Hold the mic button and talk; release to insert. Holds shorter than
   ~0.25 s (or under 0.3 s of audio) are ignored. Slide off the button to
   discard, or tap × while it's transcribing.

If cleanup fails (bad key, retired model, offline), the uncleaned
transcript is still inserted and the reason is shown under the mic button
and on the Home screen.

## Cleanup engines

| Engine | Default model | Notes |
|---|---|---|
| Anthropic | `claude-haiku-5-5` | Current models get `output_config.effort: low` and no `temperature`; Claude 3.x / 4.0–4.6 keep `temperature: 0.1`. |
| OpenAI-compatible | per preset | Presets: GitHub Models, OpenAI, OpenRouter, Groq, Ollama, OpenCode (`anthropic/claude-haiku-5-5`), Custom. |
| GitHub Copilot | `gpt-4o-mini` | OAuth device flow; session token refreshed automatically. |
| On-device | Gemma 3 1B | MediaPipe, fully offline. |

For OpenAI-compatible and Copilot endpoints, if a model rejects `temperature`
or `max_tokens` (HTTP 400), the request is retried once without
`temperature` / with `max_completion_tokens`, and that adjustment is
remembered for the model until the app process ends.

## Privacy and data flow

- **Audio** is captured only while the mic button is held, kept in memory,
  transcribed on-device, and discarded. It is never written to disk or sent
  anywhere. The microphone is released as soon as you let go, cancel, or the
  keyboard is hidden.
- **Transcripts** are sent off the device only when cleanup is on and a cloud
  engine is selected — just the text, to the provider you configured. They
  are not logged (logcat shows sample counts and timings only).
- **API keys and the Copilot OAuth token** live only in
  `EncryptedSharedPreferences` (`neelspeak_secrets`, AES-256, Keystore-backed
  key). Dart can store or clear them but never reads them back; config
  screens only show whether a key is saved. Error messages shown in the app
  are scrubbed of anything that looks like a key or token.
- **Backups** (`res/xml/data_extraction_rules.xml`, `backup_rules.xml`)
  include only the plain settings file. The encrypted secrets are excluded —
  their Keystore key can't move to another device, so a restored copy would be
  unreadable — and so are the downloaded models. After restoring to a new
  phone, re-enter keys and download the model again (Home shows a checklist).
- **Network**: HTTPS only, except plain HTTP to `localhost`, `127.0.0.1` and
  `10.0.2.2` for local Ollama / OpenCode servers
  (`res/xml/network_security_config.xml`). Network calls the app makes: the
  model download (GitHub releases), and — only if you enable them — your
  chosen cleanup provider and GitHub's OAuth/Copilot endpoints.

## Smoke test

```bash
adb logcat -s NeelSpeak.AudioCapture:V NeelSpeak.STT:V NeelSpeak.Cleanup:V NeelSpeak.Coord:V NeelSpeak.Model:V CopilotAuth:V
```

Type-test in Messages, Gmail, Chrome address bar, and WhatsApp. Each app's
`InputConnection` is implemented slightly differently — verifying across the
four catches most regressions.

## Contributor attribution

Per `../../CLAUDE.md`: commits must come from `neelashkannan
<neelashkannan@users.noreply.github.com>` only. No `Co-authored-by` trailers
for AI assistants. Verify with:

```bash
git log --branches --tags --format='%an <%ae> %cn <%ce> %B' | grep -i -E 'claude|copilot|codex|anthropic|openai|co-authored' || echo 'clean'
```
