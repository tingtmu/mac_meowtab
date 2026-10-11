# Tasks

Starts after `mac-fork-baseline` is archived. Group 1 wires every new file into the project once, so later tasks never touch `project.pbxproj`. Groups 2–3 are pure logic, written test-first and fully checked by CI. Groups 4–5 are UI that CI can only build; their behaviour goes on the acceptance list, `docs/acceptance.md` (started by `mac-fork-baseline`), which the tester works through in `mac-preview-release`. Every task ends with green `build`, `build-debug`, `test` and `launch` jobs; record each task's run URL under it. The `launch` job stops at the permission screen, so it never reaches `PeekController.setUp()`; it proves only that the app still starts. Upstream line numbers in `src/App.swift` and `SettingsWindow.swift` moved in `mac-fork-baseline` (for example the `App.swift:527` hook, `_ = TilesPanel()`, is now at `:512`); re-locate by symbol.

## 1. Skeleton

- [x] 1.1 Add the files of design.md 1 as compiling stubs. In each of the three test files, one trivial test asserts that `Mood.allCases.count == 3`. Copy the three PNGs from Windows MeowTab `images/` (commit `ed4602f`) to `resources/meowtab/`, then wire everything into `project.pbxproj` (design.md 10). Verify:
  - the three test files' tests run on all three runners;
  - a new `build` step lists `MeowTab.app/Contents/Resources/chill_{few,some,many}.png`;
  - `shasum -a 256` of those files matches the Windows copies, with the expected hashes written in the step.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38123798922 (`2da3d61`): all seven jobs green. `MoodPeekTests`, `PeekPictureTests` and `MeowTabStoreTests` passed on macos-15, macos-15-intel and macos-26. Xcode's `copypng` left the pictures unchanged: "Check bundled pictures" printed `OK` for all three.
- [x] 1.2 Add the cat pictures' MIT notice ("Copyright (c) 2026 tingwei") to `docs/acknowledgments.md`, and a `### mac-png-peek` section to `NOTICE.md`'s Modifications, in the style of the `mac-fork-baseline` section. Verify by reading both.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38123337080 (`174f78b`): all seven jobs green. Both files read back; the licence paragraphs match Windows MeowTab's `LICENSE` word for word, one line each for the app's line-by-line Markdown renderer.

## 2. Mood and geometry (test-first)

- [x] 2.1 `MoodPeek.swift`: `Mood`, `MoodSettings` (defaults, `validated()`, the clamping rules), `mood(n)` and `share(n)` (design.md 2). Write the matching `MoodPeekTests` cases from design.md 9 first. Verify: CI runs the new cases, and they pass on all three runners.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38125401209 (`6cfa469`): all seven jobs green. All 13 `MoodPeekTests` cases passed on macos-15, macos-15-intel and macos-26 (1498 tests, 0 failures, on each).
- [x] 2.2 `PeekGeometry` in `MoodPeek.swift`: `pictureSize`, `up(n)`, `reserve`, box scale, pane cap, pane origin and peek frame (design.md 3–4). Use plain `CGRect`/`CGSize` inputs, not `NSScreen`. Write the geometry cases from design.md 9 first. Verify: they pass on all three runners.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38126187580 (`853d814`): all seven jobs green. The 16 new geometry cases pass, so all 29 `MoodPeekTests` cases pass on macos-15, macos-15-intel and macos-26 (1514 tests, 0 failures, on each). Design 9's shrink example moved from 600 to 400 pt: a 160-pt box never needs more than 30 % of 600.

## 3. Pictures and storage (test-first)

- [x] 3.1 `PeekPicture.load(url:)` with the steps and errors of design.md 6, plus `pngData()`. Write the `PeekPictureTests` cases, with their runtime fixtures, first. Verify: all pass on all three runners. Note under this task whether the APNG case passed through `CGImageSourceGetCount`, or needed the `acTL` fallback.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38128856406 (`1a7cf87`): all seven jobs green. All 11 `PeekPictureTests` cases pass on macos-15, macos-15-intel and macos-26.
  - **APNG:** `CGImageSourceGetCount` reports both frames of the APNG that ImageIO writes, so `testTwoFrameAPNGIsAnimated` passes without the `acTL` fallback, which was not added.
  - **Truncated files:** a missing `IEND` chunk, rather than ImageIO's frame status, marks them unreadable (design.md 6).
- [x] 3.2 `MeowTabStore` (design.md 7): keys, `load()` with warnings, `setPicture`, `clearPicture`, `restoreDefaults`, `removeOrphans`. Write the `MeowTabStoreTests` cases first. Verify: all pass on all three runners, and nothing outside the temporary suite or folder is written (the tests assert that `UserDefaults.standard` has no `meowtab.` key afterwards).
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38128868194 (`0b4b5fb`): all seven jobs green. All 15 `MeowTabStoreTests` cases pass on all three runners (1538 tests, 0 failures, on each). `tearDown` asserts that `UserDefaults.standard` has no `meowtab.` key after every test. Picture names that aren't MeowTab's own `<mood>-<UUID>.png` are never read or deleted.

## 4. The peek in the switcher

- [x] 4.1 `PeekPanel` and `PeekController` (design.md 5 and 7):
  - `setUp()`, `reload()` with fallback warnings, `update`, `show`, `hide`, `positionPane` and `maxContentHeight`;
  - the timing log;
  - the `App.swift:527` hook.

  Verify: CI builds with no warnings, and the launch job passes.
  - https://github.com/tingtmu/mac_meowtab/actions/runs/38129165308 (`6988de1`): all seven jobs green. Release (universal) and Debug compile with warnings as errors, and both launch jobs pass.
  - Until `setUp` has run, every hook leaves the switcher as upstream's. A shipped picture that fails to load is logged, and the peek stays off rather than crashing.
- [ ] 4.2 The five `TilesPanel.swift` hooks of design.md 5, each one line marked `// MeowTab:`. Verify:
  - CI builds;
  - upstream's tile-layout tests still pass;
  - `git diff 6d8940b5307d7348aaca70259c28147fc5ab00b3 -- src/switcher/main-window/TilesPanel.swift` shows only the marked lines.

  Add these to the acceptance list (`mood-peek` spec): picture placement, the scrolled grid with placeholders, typing a search, closing a window while open, Esc-and-reopen, a click on the picture, VoiceOver, two displays, fullscreen Space, and the timing log.
- [ ] 4.3 (optional, time-boxed to 3 hours) The CI screenshot spike of design.md 11, as a separate job that runs only on manual dispatch (`if: github.event_name == 'workflow_dispatch'`). Verify: either a screenshot artifact shows the peek above a 3-window switcher, or this task records which step failed and the job is removed.

## 5. MeowTab settings section

- [ ] 5.1 `MeowTabSettingsTab`: the section entry and both cleanup calls in `SettingsWindow.swift` (design.md 8); the steppers, sliders, Restore defaults and the message line, wired to `MeowTabStore` and `PeekController.reload`. Verify: CI builds. Add the "First use", "Pushing a threshold" and "Restore defaults" scenarios of the `peek-settings` spec to the acceptance list, and add MeowTab to the section list in the existing "offline-app | Settings window" row.
- [ ] 5.2 `PictureCard`: Choose… (`NSOpenPanel`, PNG only), drop target, Use default, background import, and the error messages of design.md 6. Verify: CI builds. Add every `peek-settings` import and storage scenario to the acceptance list.

## 6. Docs and close

- [ ] 6.1 README:
  - a "The peek" section (moods, defaults, how high it rises);
  - "Use your own pictures" (PNG only, the limits, where copies are kept, that originals can be moved);
  - "Remove MeowTab's data" (`rm -r ~/Library/Application\ Support/MeowTab` and `defaults delete io.github.tingtmu.meowtab.macos`);
  - known limits (still pictures only; the sidebar icon is a star until a paw glyph is added).

  Mark ROADMAP's MVP peek item done. Verify by reading the README against both specs.
- [ ] 6.2 On the latest `main` run, confirm that every automated check above is green and that the acceptance list holds every scenario not covered by unit tests. Then archive this change (`openspec archive mac-png-peek`).
