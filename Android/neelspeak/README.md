# NeelSpeak Android

Voice-typing keyboard for Android. Hold the mic pill in any text field to
dictate — release to commit the cleaned transcript. Architecture mirrors the
macOS app under `../../Sources/VoiceTyper/`:

```
mic capture (AudioRecord 16 kHz mono) →
  sherpa-onnx Parakeet TDT (on-device) →
    TranscriptCorrector (regex) →
      LlmTranscriptCleaner (one of: OpenAI-compatible / Anthropic / GitHub Copilot / on-device Gemma) →
        InputConnection.commitText
```

The IME is native Kotlin (Compose). The settings/onboarding shell is Flutter.
Both processes live in the same Android package and share two
`SharedPreferences` files — settings changes from the settings UI take effect
in the IME instantly.

## Layout

```
lib/                                  Flutter — settings & onboarding
  main.dart                           ProviderScope + route gate
  pages/onboarding/onboarding_flow.dart 5-step welcome → IME enable → engine pick
  pages/settings/*.dart               engine config + test cleanup
  state/settings_provider.dart        Riverpod bridge to platform channels
  platform/channels.dart              Dart facades for the MethodChannels
android/app/src/main/kotlin/com/neelspeak/
  ime/NeelSpeakImeService.kt          InputMethodService — hosts the Compose pill
  ime/MicPillComposable.kt            Responsive press-and-hold pill (states: idle / recording / transcribing / cleaning / error)
  audio/AudioCapture.kt               AudioRecord at 16 kHz mono PCM16
  stt/ParakeetSherpaEngine.kt         sherpa-onnx OfflineRecognizer wrapper (Parakeet TDT)
  stt/ModelDownloader.kt              Resumable HTTPS download
  cleanup/CleanupMode.kt              Verbatim port of CleanupMode.swift (prompts + few-shot examples)
  cleanup/TranscriptCorrector.kt      Verbatim port of the regex pipeline
  cleanup/{OpenAi,Anthropic,Copilot}CleanupClient.kt   HTTP clients
  cleanup/CopilotAuthService.kt       GitHub Copilot OAuth device flow
  cleanup/OnDeviceLlmClient.kt        MediaPipe LLM Inference (Gemma 3 1B int4)
  coordinator/DictationCoordinator.kt State machine: idle → recording → transcribing → cleaning → idle
  prefs/{Settings,SecureStore}.kt     SharedPreferences + EncryptedSharedPreferences
  bridge/*.kt                         MethodChannel handlers
```

## Build (one-time setup)

You need **Flutter 3.22+**, **Android Studio Hedgehog or newer**, JDK 17, and
the Android SDK with build-tools 34. Then:

```bash
cd Android/neelspeak

# 1. Fill in the standard Flutter scaffolding (gradle wrapper jar, MainActivity
#    stubs, mipmap PNGs etc.) on top of the source files in this repo.
flutter create . \
  --project-name neelspeak \
  --org com.neelspeak \
  --platforms=android

# 2. Pull Dart dependencies.
flutter pub get

# 3. Drop the sherpa-onnx Android AAR into android/app/libs/
#    Download the latest sherpa-onnx-X.Y.Z.aar from:
#      https://github.com/k2-fsa/sherpa-onnx/releases
mkdir -p android/app/libs
# curl -L -o android/app/libs/sherpa-onnx.aar <url-to-aar>

# 4. Build a debug APK and install on a connected device.
flutter run
# or, for a release APK without Flutter logging:
flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> Note: `flutter create .` overwrites a handful of generic files (e.g.
> AndroidManifest.xml may be overwritten — re-merge by keeping ours). After
> `flutter create .`, re-apply the manifest from version control if it changed:
> `git checkout -- android/app/src/main/AndroidManifest.xml android/app/src/main/res/xml/method.xml`.

## Model setup (first run)

The IME requires the Parakeet TDT INT8 model (~190 MB). The onboarding flow
downloads it, but you can also place it manually at:

```
/data/data/com.neelspeak/files/models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8/
  encoder.int8.onnx
  decoder.int8.onnx
  joiner.int8.onnx
  tokens.txt
```

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

## Enabling NeelSpeak as your keyboard

1. Launch the NeelSpeak app to grant microphone permission.
2. **Settings → System → Languages & input → On-screen keyboard → Manage keyboards** → toggle **NeelSpeak**.
3. Tap any text field, then in the keyboard-switcher notification select **NeelSpeak**.
4. Hold the mic pill to dictate.

The onboarding flow walks the user through this on first run.

## Smoke test

```bash
adb logcat -s NeelSpeak.AudioCapture:V NeelSpeak.STT:V NeelSpeak.Cleanup:V NeelSpeak.Coord:V CopilotAuth:V
```

Type-test in Messages, Gmail, Chrome address bar, and WhatsApp. Each app's
`InputConnection` is implemented slightly differently — verifying across the
four catches most regressions.

Latency expectations on a Pixel 7 / SD8G2: ~300–500 ms end-to-end for a 10-second
utterance with cloud cleanup. Mid-range SD7 / Tensor G2 phones: ~600–1200 ms.

## Contributor attribution

Per `../../CLAUDE.md`: commits must come from `neelashkannan
<neelashkannan@users.noreply.github.com>` only. No `Co-authored-by` trailers
for AI assistants. Verify with:

```bash
git log --branches --tags --format='%an <%ae> %cn <%ce> %B' | grep -i -E 'claude|copilot|codex|anthropic|openai|co-authored' || echo 'clean'
```
