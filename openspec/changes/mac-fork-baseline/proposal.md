# Proposal

First of three changes for MeowTab for Mac: **mac-fork-baseline** → `mac-png-peek` → `mac-preview-release`.

## Why

MeowTab's peek needs a Mac window switcher underneath it. AltTab v11.9.0 is mature and GPL-3.0, so the Mac app starts as a fork of it. Before any MeowTab feature goes in, the fork has to be its own app:

- **Its own identity, so it runs next to AltTab.** Preferences, the login item, the licence Keychain entry, the URL scheme and macOS permissions are all keyed on the bundle ID.
- **No traffic to AltTab's servers.** An unchanged fork would check AltTab's appcast and update itself into upstream AltTab. It would also count down a Pro trial against AltTab's licence server.
- **A CI that builds and tests it without upstream's secrets.** The developer has no Mac.

## What Changes

- **The fork.** `tingtmu/mac_meowtab` is a GitHub fork of `lwouis/alt-tab-macos`. Its `main` branch starts at v11.9.0 (`6d8940b5307d7348aaca70259c28147fc5ab00b3`) and keeps upstream's history and an `upstream` remote. This folder becomes the checkout. Its `openspec/` and `ROADMAP.md` are committed with the first commit, and upstream's `CLAUDE.md` and `AGENTS.md` are removed. The project's `CLAUDE.md` stays local and git-ignored.
- **Its own identity.** The app is `MeowTab.app`, with bundle ID `io.github.tingtmu.meowtab.macos` and version 0.1.0. Everything keyed on the bundle ID separates from an installed AltTab with no further code.
- **Offline.** Sparkle's updater is never created and AppCenter crash reporting never starts. The menu loses Check for updates, Send feedback, Get Pro, My Account and Support this project. Settings loses the updates rows and the Upgrade entry.
- **Pro unlocked.** The licence state is permanently Pro: no trial, upsell or licence server. All of AltTab's features stay available.
- **Credit and GPL-3.0.** The README's first screen, the About window and a new `NOTICE.md` credit AltTab and its author, Louis Pontoise. They link the upstream repo (github.com/lwouis/alt-tab-macos) and his sponsor page (github.com/sponsors/lwouis), and state what the fork changed and when (GPL-3.0 §5a). `LICENCE.md` and the third-party notices stay as they are.
- **CI.** One new workflow replaces upstream's release pipeline and needs no secrets:
  - It builds a universal (arm64 + x86_64), ad-hoc-signed Release app.
  - It runs upstream's unit tests on macos-15 (Apple silicon), macos-15-intel and macos-26.
  - It launches the app on an Apple silicon and an Intel runner to check that it starts.
  - It guards the offline cuts with static checks.
- **Unchanged.** Everything else AltTab does stays: switching, previews, search, shortcuts, settings, permissions, localization, and launch at login (on by default, as upstream). Trimming AltTab down is a later change (see ROADMAP).
- **Out of scope:** the peek and its settings (`mac-png-peek`), and signed, user-facing releases (`mac-preview-release`).

## Capabilities

### New Capabilities

- `fork-identity`: name, bundle ID and version; separation from AltTab; credit and GPL-3.0 notices.
- `offline-app`: no app-initiated network traffic, no automatic update, and Pro features without a licence.
- `mac-ci`: universal build, unit tests and a launch check on GitHub-hosted runners, without secrets.

### Modified Capabilities

None.

## Impact

- **Build:** `config/base.xcconfig` (product name and bundle ID); a new `MEOWTAB_VERSION` file; a CI-written `config/local.xcconfig` (already git-ignored upstream); the product reference in `alt-tab-macos.xcodeproj/project.pbxproj` and `BuildableName` in the `Debug` and `Release` schemes.
- **App code:**
  - `src/App.swift`: superclass, AppCenter and Sparkle start, licence URL handler, repository URL.
  - `src/Info.plist`
  - `src/Menubar.swift`
  - `src/pro/license/LicenseManager.swift`
  - `src/preferences/settings-window/SettingsWindow.swift`
  - `src/preferences/settings-window/tabs/GeneralTab.swift` and `AboutTab.swift`
- **CI:** `.github/workflows/ci_cd.yml` is deleted; new `.github/workflows/ci.yml` and `scripts/meowtab/check_offline.sh`.
- **Docs:** `README.md` replaced; new `NOTICE.md`; new `docs/acceptance.md` (the manual checklist for the real-Mac test); one line added to `docs/acknowledgments.md`.
- **Packages:** Sparkle and AppCenter stay linked but inert. Removing the packages touches the project file, two build phases and seven Swift files, so it belongs with the later trimming change.
