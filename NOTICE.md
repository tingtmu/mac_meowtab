# Notice

MeowTab for Mac is a modified version of [AltTab](https://github.com/lwouis/alt-tab-macos) by Louis Pontoise and contributors.

- **Based on:** AltTab v11.9.0, commit `6d8940b5307d7348aaca70259c28147fc5ab00b3`.
- **Modified by:** tingtmu, starting October 2026.
- **Licence:** GNU General Public License v3.0, the same as AltTab. See [LICENCE.md](LICENCE.md), which is unchanged from upstream.
- **Third-party notices:** [docs/acknowledgments.md](docs/acknowledgments.md).

## Modifications

Listed by OpenSpec change name. Later changes are appended here.

### mac-fork-baseline

- **Rename:** the app is `MeowTab.app`, with bundle ID `io.github.tingtmu.meowtab.macos` and its own version, so it runs beside AltTab.
- **Offline:** AltTab's updater, crash reporting and feedback form are cut off, and the menu and settings entries that reached them are removed, so the app makes no network traffic of its own.
- **Pro unlocked:** the licence state is permanently Pro, with no trial, upsell or licence server.
- **Credit:** the README, the About window and this notice credit AltTab and its author, and link its repository and the author's sponsor page.
- **CI:** one new GitHub Actions workflow (`.github/workflows/ci.yml`) replaces upstream's release pipeline. It builds, tests and launch-checks the app without secrets.

### mac-png-peek

- **The peek:** a cat picture on the switcher's top-left edge, with three moods by window count. The switcher's pane leaves room so the picture always fits on screen.
- **Settings:** a MeowTab section, first in the Settings sidebar, sets each mood's picture, the mood thresholds and the peek height. Users' own PNGs are copied to `~/Library/Application Support/MeowTab/images/`.
- **Upstream code:** one-line hooks, each marked `// MeowTab:`, in `src/App.swift`, `src/switcher/main-window/TilesPanel.swift`, `src/switcher/search-discovery/SearchDiscoveryHint.swift` and `src/preferences/settings-window/SettingsWindow.swift`. The new code is in `src/meowtab/`.
- **Pictures:** the three cat PNGs from Windows MeowTab (MIT licence, see `docs/acknowledgments.md`) ship in `resources/meowtab/`.

### mac-preview-release

- **Signing:** upstream's `scripts/codesign/generate_selfsigned_certificate.sh` takes an optional certificate name and validity. Releases are signed with the project's own self-signed certificate, so macOS keeps the permissions users grant through updates. They are not notarized.
- **Releases:** a new workflow, `.github/workflows/release.yml`, runs the CI workflow, then packages the signed app with `INSTALL.md`, `LICENCE.md` and this notice as a zip, with its SHA-256, in a draft GitHub release. The CI build steps moved into `scripts/meowtab/build.sh`.

### mac-easy-install

- **Scripts:** `scripts/meowtab/install.sh` and `scripts/meowtab/uninstall.sh` install, update and remove MeowTab with one Terminal command each. The install script checks the download's SHA-256, the app's signature and its designated requirement before it replaces anything.
- **CI:** a new workflow, `.github/workflows/install-scripts.yml`, runs both scripts on macOS 15 and macOS 26 whenever either changes.
- **Docs:** `docs/install.md` gains a "Quick install from Terminal" section, which comes first, ahead of "Install by hand"; the README's Install section leads with the same command and puts the download by hand after it; and `docs/acceptance.md` gains rows 42 and 43.
- **App:** unchanged.
