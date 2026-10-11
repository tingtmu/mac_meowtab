# MeowTab for Mac

MeowTab for Mac is a modified version of [AltTab](https://github.com/lwouis/alt-tab-macos), the window switcher by Louis Pontoise and contributors. Everything that makes this a good switcher is their work, and we are grateful for it. If AltTab is useful to you, please consider [sponsoring its author](https://github.com/sponsors/lwouis).

AltTab and MeowTab are free software under the GNU General Public License v3.0 (see [LICENCE.md](LICENCE.md)). [NOTICE.md](NOTICE.md) says what this fork changed.

## Status

In development. There are no downloads or releases yet. CI builds are ad-hoc-signed test builds: macOS forgets the Accessibility and Screen Recording permissions you grant on every new build, so they are not for daily use. The plan is in [`openspec/`](openspec/) and [`ROADMAP.md`](ROADMAP.md).

## What MeowTab adds

Nothing you can see yet. The mood-picture peek comes next: see [`mac-png-peek`](openspec/changes/mac-png-peek/proposal.md).

What this fork changes from AltTab:

- Its own name and bundle ID, so it runs beside AltTab without sharing settings or permissions.
- No update checks, crash reporting, licence server or feedback form, so it makes no network traffic of its own.
- AltTab's Pro features are unlocked, with no trial.

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
- The About window's "Website" link still points to AltTab's website.

## Building

CI (`.github/workflows/ci.yml`) builds a universal (arm64 and x86_64), ad-hoc-signed Release app with Xcode 26.0.1 and uses no secrets. It has three jobs:

- `build` checks that `LICENCE.md` is unchanged from AltTab v11.9.0, builds the app, checks its architectures, signature and identity, and uploads a zip.
- `test` runs the unit tests on macOS 15 (Apple silicon), macOS 15 (Intel) and macOS 26 (Apple silicon).
- `launch` installs the built app on the two macOS 15 runners, starts it, and checks that it stays running with no internet sockets and no crash report.

To get the app, open the Actions tab on GitHub, pick the latest run on `main`, and download the `MeowTab-<commit>.zip` artifact.
