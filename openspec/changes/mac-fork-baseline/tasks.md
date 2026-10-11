# Tasks

All work happens in the `tingtmu/mac_meowtab` repository, checked out in this folder. Group 1 gets unmodified upstream code green on CI first, so every later failure is ours. Groups 2–3 change code, and each task ends with a green CI run. Record each task's CI run URL under it.

## 1. Fork and a green baseline

- [x] 1.1 Set up `main` as in design.md 1: remotes, `main` at `6d8940b5307d7348aaca70259c28147fc5ab00b3`, upstream's `CLAUDE.md` and `AGENTS.md` removed, `/CLAUDE.md` ignored, local excludes. Verify: `git merge-base --is-ancestor 6d8940b5307d7348aaca70259c28147fc5ab00b3 HEAD` succeeds; `git diff --stat 6d8940b5307d7348aaca70259c28147fc5ab00b3` lists only `openspec/`, `ROADMAP.md`, `.gitignore`, `project.pbxproj`, the two deletions and the workflow files of 1.2; `git check-ignore -q CLAUDE.md` succeeds.
- [x] 1.2 In the same commit, delete `.github/workflows/ci_cd.yml` and add `.github/workflows/ci.yml` with the `build` and `test` jobs of design.md 6. Push `main`, make it the default branch, and enable Actions. Verify: the first run on unmodified upstream code (still `AltTab.app`) builds a universal artifact, and the test jobs pass on `macos-15`, `macos-15-intel` and `macos-26`, each summary showing its OS, architecture and Xcode. Record the run URL as the baseline.
  - Baseline: https://github.com/tingtmu/mac_meowtab/actions/runs/38107403004 (`519fa39`): `lipo` `x86_64 arm64`, `codesign` valid; tests green on all three runners. The summary step now also prints to the log (`tee`), so later runs can be checked with `gh run view --log`.
- [x] 1.3 Add the `launch` job (design.md 6), temporarily pointed at `AltTab.app`. Verify: on unmodified code the app stays running for 20 s with no internet sockets on both runners. This proves the check works before we rely on it.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38107508867 (`42be49a`): both launch jobs green; ad-hoc `AltTab.app` running after 20 s, no sockets, no crash report.

## 2. Identity and credit

- [x] 2.1 Rename (design.md 2):
  - `config/base.xcconfig:3-4`;
  - the `AltTab.app` product reference in `project.pbxproj` (854, 1519, 2011);
  - `BuildableName` in `Debug.xcscheme` and `Release.xcscheme`;
  - a new `MEOWTAB_VERSION` (`0.1.0`), and CI writing it into `config/local.xcconfig`;
  - point the `build` and `launch` jobs at `MeowTab.app`.

  Verify: the `build` job's `PlistBuddy` step asserts the bundle ID, `CFBundleName` `MeowTab`, version `0.1.0` and `LSMinimumSystemVersion` `12.0`. The `launch` job passes with `pgrep -x MeowTab`.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38107835080 (`2d7d8e2`): identity `io.github.tingtmu.meowtab.macos` / `MeowTab` / `0.1.0` / `12.0`; both launch jobs green.
- [x] 2.2 Update the About window (design.md 5):
  - `App.swift:17` → the fork URL;
  - a "Based on AltTab" link in `AboutTab.swift:10-16`;
  - the support button relabelled "Sponsor AltTab's author", with `App.supportProject` (`App.swift:145-147`) opening github.com/sponsors/lwouis.

  Verify: CI builds, and `grep` finds both URLs in `src/`. Create `docs/acceptance.md`, the checklist the tester works through in `mac-preview-release`. Give it one row per manual check (spec, scenario, result, notes), and add the `fork-identity` "About window" and "Supporting the author from the app" scenarios.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38107885382 (`e5a57a5`): build, tests and launch green; `App.swift:17` has the fork URL and `Endpoints.swift:8` the sponsors URL; `docs/acceptance.md` created.
- [x] 2.3 Write the repository's notices (design.md 5):
  - replace `README.md`: credit block first, then status, what MeowTab adds (nothing yet), compatibility (target 12.0+; CI-tested versions; 12–14 untested), known issues (about ten "AltTab" strings, launch at login on by default), and how CI builds it;
  - add `NOTICE.md`;
  - add one line to `docs/acknowledgments.md`;
  - add the `LICENCE.md` comparison step to `build`.

  Verify: the comparison passes, and reading README.md against the `fork-identity` spec finds every required item.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38108051581 (`3b4046e`): licence check green; README checked against `fork-identity` and `mac-ci` "Honest coverage".

## 3. Offline and Pro unlocked

- [x] 3.1 Sparkle (design.md 3):
  - delete `App.swift:564-575`;
  - remove `GeneralTab.swift:24-26` and the layout rows that place them;
  - remove `Menubar.swift:40`;
  - in `Info.plist`, delete `SUPublicEDKey` and set `SUEnableAutomaticChecks` to false.

  Verify: CI builds and tests pass (no warnings, as warnings are errors), and a `PlistBuddy` step confirms both keys.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38108281949 (`e14cef0`): green; `SUPublicEDKey` absent, `SUEnableAutomaticChecks = false`.
- [x] 3.2 AppCenter (design.md 3):
  - `App.swift:7` → `class App: NSApplication`;
  - delete `App.swift:38` and `:604`;
  - in `Info.plist`, set `NSPrincipalClass` to `NSApplication` and delete the AppCenter keys at 69-74;
  - remove the "Crash reports policy" row in Settings > General.

  Verify: build, test and `launch` pass on both architectures; the launch job is what catches a startup crash from the superclass change.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38108861497 (`15b3fd4`): green, both launch jobs included. `NSApplicationCrashOnExceptions` is registered where `AppCenterCrash` used to do it, keeping upstream's crash-on-exception behaviour.
- [ ] 3.3 Licence and Pro (design.md 3–4):
  - the `ProLicenseManager` subclass behind `LicenseManager.shared` (design.md 4);
  - delete `App.swift:677-702`;
  - remove the Upgrade entry (`SettingsWindow.swift:319`, `536-553`);
  - remove `Menubar.swift:45-49`.

  Verify: the upstream test suite passes unchanged on all three runners. Add the `offline-app` "Weeks after installing" and "Settings window" scenarios, and the "Both apps installed" scenario of `fork-identity`, to `docs/acceptance.md`.
- [ ] 3.4 Add `scripts/meowtab/check_offline.sh` with the checks of design.md 3, and run it from `build` as `bash scripts/meowtab/check_offline.sh`. Verify: it passes on `main`. On a throwaway branch, restoring `App.swift:604` makes it fail. Delete that branch.

## 4. Close

- [ ] 4.1 Confirm the `mac-ci` spec end to end on the latest `main` run: artifact, three test jobs with summaries, two launch jobs, and the offline and licence checks. Then archive this change (`openspec archive mac-fork-baseline`), so its specs land in `openspec/specs/` before `mac-png-peek` starts.
