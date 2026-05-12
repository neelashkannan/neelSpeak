# NeelSpeak Workspace Instructions

## Project Overview
This is **NeelSpeak** (formerly VoiceTyper), a macOS voice-to-text dictation application built with Swift. It uses on-device speech recognition (Whisper/Parakeet models) and requires system-level permissions (Accessibility, Microphone).

## Critical Deployment Requirement

**⚠️ MANDATORY: Full Uninstall and Reinstall After Every Change**

Whenever **any** code changes are made to this application, it **MUST** be fully uninstalled and reinstalled before testing. This is not optional.

### Why This Is Required

1. **TCC Permission Caching**: macOS caches Accessibility and Microphone permissions per app bundle. Partial updates can leave stale permission state.
2. **Code Signing**: The app is ad-hoc signed with entitlements. Modified binaries without proper reinstallation may be rejected by the OS.
3. **Bundle Identity**: The app has migrated from `com.voicetyper.app` to `com.neelspeak.app`. Stale preferences or permission rows from old bundle IDs can cause conflicts.
4. **State Corruption**: User preferences, model caches, and system integration state must be cleared to ensure clean testing.

### Deployment Workflow

**Always use the redeploy script after making changes:**

```bash
./Scripts/redeploy-app.sh
```

This script performs a complete clean deployment cycle:
- Kills all running app processes
- Resets TCC permissions (Accessibility & Microphone) for both old and new bundle IDs
- Clears all app preferences from `defaults`
- Removes all existing app copies from `/Applications`, `~/Applications`, and build directories
- Stages the Parakeet model
- Rebuilds the app bundle from source
- Installs the fresh build to `/Applications/NeelSpeak.app`
- Removes quarantine attributes
- Verifies code signature
- Launches the new version

**After deployment**, you must manually re-grant permissions:
- System Settings → Privacy & Security → Accessibility → Enable NeelSpeak
- System Settings → Privacy & Security → Microphone → Enable NeelSpeak

### Never Do This

❌ Do NOT run just `swift build` and expect the running app to pick up changes  
❌ Do NOT copy-paste modified binaries into the existing bundle  
❌ Do NOT use `open NeelSpeak.app` on a partially updated bundle  
❌ Do NOT skip the redeploy step "just this once"

### Build-Only (No Install)

If you need to build without installing (e.g., for syntax checking or CI):

```bash
./Scripts/build-app.sh
```

This only compiles and assembles the bundle at `./NeelSpeak.app`, but does not install or clean system state.

## Development Notes

- **Bundle ID**: `com.neelspeak.app` (formerly `com.voicetyper.app`)
- **Target Platform**: macOS (arm64)
- **Build System**: Swift Package Manager
- **Entitlements**: Microphone, Accessibility, Audio Input (see `Resources/VoiceTyper.entitlements`)
- **Models**: Parakeet model staged via `Scripts/stage-parakeet.sh`

## File Restrictions

None currently defined.

---

**Summary**: After every code change, run `./Scripts/redeploy-app.sh` to ensure clean, testable state. No exceptions.
