# NeelSpeak v0.2.1

This release polishes NeelSpeak's macOS UI and ships the new app and menu bar icons.

## What's new

- New custom app icon is bundled into `NeelSpeak.app` and used throughout the dashboard.
- New custom menu bar icon replaces the previous text-heavy status item.
- The control centre has been tightened into a cleaner split layout with a slim header, cleanup settings, recent dictations, status, and pill appearance controls.
- Release packaging now includes PNG and ICNS image assets so the icons are present in local builds and GitHub release DMGs.

## Version comparison

| Area | v0.2.0 | v0.2.1 |
|------|--------|--------|
| Dashboard | Full cleanup/provider configuration, overlay themes, and transcript history | Compact control centre with cleanup, recent dictations, status, and appearance panels |
| Menu bar | SF Symbol plus text label | Custom icon-only menu bar item |
| App identity | Default/generated visual mark in some surfaces | Bundled app icon reused in app metadata and dashboard |
| Packaging | DMG-first release workflow | DMG release includes app/menu icon PNG and ICNS assets |

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
