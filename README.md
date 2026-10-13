# MeowTab for Mac

MeowTab for Mac is a modified version of [AltTab](https://github.com/lwouis/alt-tab-macos), the window switcher by Louis Pontoise and contributors. Everything that makes this a good switcher is their work, and we are grateful for it. If AltTab is useful to you, please consider [sponsoring its author](https://github.com/sponsors/lwouis).

AltTab and MeowTab are free software under the GNU General Public License v3.0 (see [LICENCE.md](LICENCE.md)). [NOTICE.md](NOTICE.md) says what this fork changed.

## Status

In development. Test candidates for a real-Mac acceptance run are published as they're ready (see [Download](#download)), and the 0.1.0 preview follows once one passes. CI builds are ad-hoc-signed test builds: macOS forgets the Accessibility and Screen Recording permissions you grant on every new build, so they are not for daily use. The plan is in [`ROADMAP.md`](ROADMAP.md).

## What MeowTab adds

The peek is a cat picture on the switcher's top-left edge, with a mood that changes with how many windows are open: see [The peek](#the-peek). A MeowTab section in Settings lets you tune the peek and choose your own pictures: see [Use your own pictures](#use-your-own-pictures).

What this fork changes from AltTab:

- Its own name and bundle ID, so it runs beside AltTab without sharing settings or permissions.
- No update checks, crash reporting, licence server or feedback form, so it makes no network traffic of its own.
- AltTab's Pro features are unlocked, with no trial.

## Download

Releases are on the [releases page](https://github.com/tingtmu/mac_meowtab/releases).

Each release has:

- `MeowTab-<version>-mac.zip`: the app, with `INSTALL.md`, `LICENCE.md` and `NOTICE.md`. `<version>` is the release's tag, such as `v0.1.0-rc.1`.
- `SHA256SUMS.txt`: the zip's SHA-256 hash, to check your download.

Test candidates (`vX.Y.Z-rc.N`) are pre-releases labelled "Test candidate — not yet checked on a real Mac". The preview (`v0.1.0`) is published only after a candidate passes an acceptance run on a real Mac, and it ships the same zip.

Releases are self-signed, not notarized, so macOS asks once the first time you open the app. The signature stays the same from release to release, so the permissions you grant should survive updates.

## Install

Unzip the download and move `MeowTab.app` into Applications. Open it: macOS says it was not opened, so click "Done", then click "Open Anyway" in System Settings > Privacy & Security. On macOS 14 and earlier, Control-click the app and choose "Open" instead. Then grant Accessibility, which MeowTab needs, and Screen Recording, which is optional: without it the switcher shows app icons instead of window previews.

To install from Terminal instead, without the "Open Anyway" step, run the command below with the release's tag (needed while only test candidates are published). The guide's [Quick install from Terminal](docs/install.md#quick-install-from-terminal) section says why that works and how to read the script first.

```bash
curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh | bash -s -- v0.1.0-rc.1
```

[`docs/install.md`](docs/install.md) has the steps in full, and covers running beside AltTab, launch at login, updating and removing MeowTab. It ships in each zip as `INSTALL.md`.

## The peek

The peek is a cat picture that sits on the top-left edge of the switcher's pane, the panel that holds the window tiles. It has three moods, picked by how many windows the switcher lists:

- **Few:** 1 or 2 windows.
- **Some:** 3 to 7 windows.
- **Many:** 8 or more windows.

These are the defaults. In Settings > MeowTab, "Some from" and "Many from" move the thresholds, and "With 1 window" and "With many windows" set how high the peek rises. Changes apply at once.

**What counts as a window.** The real windows the switcher lists, including ones scrolled out of view. App-only placeholder tiles don't count, and a group of tabs counts once while the switcher groups tabs, as it does by default. Typing a search doesn't change the count. With no real window, there is no picture.

**How high it rises.** By default, 80 % of the picture's art shows above the pane with 1 window. That share rises evenly to 95 % at "Many from" plus 4 windows (12 by default), and stays there. The art is the part of the picture with visible pixels, so transparent padding around the cat doesn't change how much of it shows.

**Where it sits.** The picture keeps its proportions inside a 160-point box and sits 24 points in from the pane's left edge, or further in where the pane's corners are rounder: on macOS 26 that is 43 points with thumbnails, and 50, 55 or 75 points with small, medium or large app icons. On a pane too narrow for that, such as app icons with one window, the picture shrinks to fit between the same margins. Only the part above the pane's top edge shows. The pane leaves room above itself, so the picture's top stays at least 12 points below the top of the display's usable area. That area excludes the menu bar and the Dock. When there are more windows than fit, the tiles scroll instead of the pane growing into that room. The room doesn't change while the switcher is open. The picture shrinks only on very short displays, where the room would take more than 30 % of the usable height.

The picture takes no focus and no clicks: a click on it counts as a click outside the pane. VoiceOver skips it. It is a still picture, shown with the pane: it appears when the pane does, and goes as soon as the pane starts to hide.

## Use your own pictures

Each mood has a card in Settings > MeowTab. Click "Choose…" on a card, or drop a PNG on it, to use your own picture for that mood. The card shows it at once, and the other two moods don't change.

A picture is accepted only if it is:

- a PNG, checked by its content and not by its name, so a JPEG renamed to `.png` is refused;
- a still picture, so animated PNGs and GIFs are refused;
- at most 10 MB, 8192 px a side and 32 megapixels;
- not fully or nearly fully transparent: it needs some visible pixels.

If a picture breaks a limit or can't be saved, the card keeps its old picture, and the message line under "Restore defaults" says why. A picture whose longer side is over 1024 px is scaled down to 1024 px, keeping its proportions and transparency.

MeowTab keeps its own copy of each picture in `~/Library/Application Support/MeowTab/images/`, so you can move or delete the original afterwards.

"Use default" on a card brings back that mood's cat and deletes MeowTab's copy of your picture. "Restore defaults" resets every MeowTab setting and deletes only MeowTab's own copies of your pictures. It leaves AltTab's settings alone.

## Remove MeowTab's data

MeowTab keeps its copies of your pictures in a folder, and its settings in its preferences. To delete the pictures, which leaves your original files alone:

```bash
rm -r ~/Library/Application\ Support/MeowTab
```

To reset the settings:

```bash
defaults delete io.github.tingtmu.meowtab.macos
```

The second command resets all of the app's settings, MeowTab's and AltTab's own, since they share one preferences domain.

The app also writes two small preference domains that hold no settings, so the commands above leave them. Removing them is optional. The first keeps flags for AltTab's Pro prompts:

```bash
defaults delete io.github.tingtmu.meowtab.macos.license
```

The second keeps the usage counts that the About window shows:

```bash
defaults delete io.github.tingtmu.meowtab.macos.usage
```

If "Start at login" is on, turn it off in Settings > General before you remove MeowTab. That removes its login item from `~/Library/LaunchAgents`.

## Compatibility

- **Targeted:** macOS 12.0 and later.
- **Tested by CI** on GitHub-hosted runners: macOS 15 on Apple silicon and on Intel, and macOS 26 on Apple silicon. Unit tests run on all three. A launch check runs on the two macOS 15 runners.
- **Not tested by CI:** macOS 12, 13 and 14. They are targeted, but nothing has run on them yet.

## Known issues

- Some English UI strings still say "AltTab", because changing a string drops its 20 translations. The visible ones:
  - the menu items "Quit AltTab" and "AltTab Help" (`src/MainMenu.swift`)
  - the Screen Recording callout (`src/Menubar.swift`)
  - the usage line "You have used AltTab..." in the About window (`src/preferences/settings-window/tabs/AboutTab.swift`)
  - a few others, such as the permissions window and the onboarding popover
- Launch at login is on by default, as in AltTab. Turn it off in Settings > General.
- The peek shows still pictures only: there is no GIF or animation yet.
- The MeowTab section's sidebar icon is a star until a paw glyph is added.
- Settings > General > "Export settings…" and "Import settings…" cover AltTab's settings only. Importing replaces all saved settings, so MeowTab's go back to their defaults, and its copies of your pictures are deleted the next time MeowTab starts.
- Settings > General > "Reset settings and restart…" resets MeowTab's settings too, and its copies of your pictures are deleted when it restarts.

## Building

CI (`.github/workflows/ci.yml`) builds a universal (arm64 and x86_64), ad-hoc-signed Release app with Xcode 26.0.1 and uses no secrets. It has five jobs:

- `build` checks that `LICENCE.md` is unchanged from AltTab v11.9.0, builds the app, checks its architectures, signature and identity, checks the offline cuts and the bundled cat pictures, and uploads a zip.
- `build-debug` compiles the Debug configuration too, so debug-only code can't break unnoticed.
- `test` runs the unit tests on macOS 15 (Apple silicon), macOS 15 (Intel) and macOS 26 (Apple silicon).
- `launch` installs the built app on the two macOS 15 runners, starts it, and checks that it stays running with no internet sockets and no crash report.
- `screenshot` runs only when started by hand, on the two macOS 15 runners (`macos-15` and `macos-15-intel`). It grants MeowTab its permissions, opens three TextEdit windows and the switcher, and uploads screenshots of the peek. It never fails a run.

To get the app, open the Actions tab on GitHub, pick the latest run on `main`, and download the `MeowTab-<commit>.zip` artifact.

The release workflow (`.github/workflows/release.yml`) runs on a version tag. It checks the tag against `MEOWTAB_VERSION` and runs the CI workflow. Then it builds the app signed with the project's self-signed certificate, from the repository secrets `MEOWTAB_CERT_P12` and `MEOWTAB_CERT_PASSWORD`, and checks its designated requirement against `docs/designated-requirement.txt`. It packages the zip and `SHA256SUMS.txt` and opens a draft release. Started by hand, it runs as a dry run that uploads them as artifacts instead.
