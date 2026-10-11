# Notice

MeowTab for Mac is a modified version of [AltTab](https://github.com/lwouis/alt-tab-macos) by Louis Pontoise and contributors.

- **Based on:** AltTab v11.9.0, commit `6d8940b5307d7348aaca70259c28147fc5ab00b3`.
- **Modified by:** tingtmu, starting October 2026.
- **Licence:** GNU General Public License v3.0, the same as AltTab. See [LICENCE.md](LICENCE.md), which is unchanged from upstream.
- **Third-party notices:** [docs/acknowledgments.md](docs/acknowledgments.md).

## Modifications

Listed by [OpenSpec](openspec/) change name. Later changes are appended here.

### mac-fork-baseline

- **Rename:** the app is `MeowTab.app`, with bundle ID `io.github.tingtmu.meowtab.macos` and its own version, so it runs beside AltTab.
- **Offline:** AltTab's updater, crash reporting and feedback form are cut off, and the menu and settings entries that reached them are removed, so the app makes no network traffic of its own.
- **Pro unlocked:** the licence state is permanently Pro, with no trial, upsell or licence server.
- **Credit:** the README, the About window and this notice credit AltTab and its author, and link its repository and the author's sponsor page.
- **CI:** one new GitHub Actions workflow (`.github/workflows/ci.yml`) replaces upstream's release pipeline. It builds, tests and launch-checks the app without secrets.
