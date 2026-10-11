# Design

## Context

See [proposal.md](proposal.md). This change builds on `mac-fork-baseline`: the fork is renamed, offline, Pro-unlocked and green on CI. Upstream line numbers are at v11.9.0; re-locate by symbol if `main` has moved.

| Upstream fact | Where |
| --- | --- |
| The pane is `TilesPanel`, a `.nonactivatingPanel` at level `.popUpMenu` | `TilesPanel.swift:25-42` |
| Its content size is set, then it is centred in `NSScreen.preferred.visibleFrame` | `updateContents` `:49-61`; `repositionOrFreeze` `:64-78` → `Screens.swift:112-118` |
| Its content height is capped at `screen.frame.height * 0.8 - 2 * windowPadding` | `maxThumbnailsHeight` `:144-146`; `Appearance.swift:20` |
| It is shown by `show()` and hidden by an overridden `orderOut` with a fade guarded by `showGeneration` | `:109-128`; `:85-107` |
| A ready pattern for a panel attached to the pane | `SearchDiscoveryPanel.swift:16-26`; `SearchDiscoveryHint.swift:100-103` (`level = TilesPanel.shared.level`, `addChildWindow(_, ordered: .above)`) |
| Panels are created after permissions are granted | `App.swift:527` |
| Losing Accessibility restarts the whole app | `SystemPermissions.swift:98-103` → `App.restart()` |
| Window flags | `Window.shouldShowTheUser` (`Window.swift:43`) is set by filtering, tab grouping and one-window-per-app mode. It ignores the search query, unlike `Windows.shouldDisplay` (`Windows.swift:51-53`). `Window.isWindowlessApp` marks app-only placeholders. |
| Settings sections | `SettingsWindow.sectionDefinitions()` `:569-576`. Cleanup calls at `:1266-1270` and `:1341-1345`. Sidebar icons must be existing `Symbols` cases (`TileFontIconView.swift`), because the font is a subset. |
| Tests | `unit-tests` compiles listed production files and has no app host, so new testable files must not touch `App`, `Preferences` or `NSScreen` statics |
| Project file | Every file is listed explicitly in `project.pbxproj` (no synchronized folders). The app's Resources phase is at `pbxproj:2074`. A bundled PNG is loaded the way `App.swift:18-22` loads `app.png`. |

Windows MeowTab reference:

- **Mood rules:** `SOME_FROM` 3, `MANY_FROM` 8, `PEEK_MIN` 0.80, `PEEK_MAX` 0.95, `PeekShare(n)` (`meowtab.ahk:19-23, 313-314`).
- **Rows above the pane:** `top + (bottom - top) * share` over the art span (`meowtab.ahk:297`).
- **Picture placement:** 24 px in from the pane's left edge (`PEEK_X`) and 250 px wide at 150 % scaling.
- **Shipped pictures:** 512×512 with centred art 482–484 px tall, where "art" means alpha > 24 (`openspec/specs/mood-pictures/spec.md` there).

## Goals / Non-Goals

**Goals:**

- The peek behaves like Windows MeowTab's static peek.
- Upstream files get only one-line hooks.
- All logic that can be tested without a desktop is unit-tested on CI.
- The switching path never touches the disk.

**Non-Goals:** GIF or animation, background cleaning, slide-up motion, preview scenes in Settings, and changing AltTab's own layout rules beyond reserving the peek's room.

## Decisions

### 1. New files and target membership

| File | Targets | Contents |
| --- | --- | --- |
| `src/meowtab/MoodPeek.swift` | app, unit-tests | `Mood`, `MoodSettings` and `PeekGeometry`. Pure Swift with CoreGraphics types only. |
| `src/meowtab/PeekPicture.swift` | app, unit-tests | PNG import, normalization, art span and PNG encoding (ImageIO and CoreGraphics). |
| `src/meowtab/MeowTabStore.swift` | app, unit-tests | Settings in `UserDefaults` and the picture folder. The store and folder are injected. |
| `src/meowtab/PeekPanel.swift` | app | `PeekPanel` (`NSPanel`) and `PeekController` (static, upstream style). |
| `src/meowtab/MeowTabSettingsTab.swift` | app | The settings section. |
| `src/meowtab/*Tests.swift` (3 files) | unit-tests | Next to their sources, following upstream's placement. |
| `resources/meowtab/chill_{few,some,many}.png` | app (Resources) | Byte-identical copies of Windows MeowTab's `images/chill_*.png` at commit `ed4602f`. |

Constants live in `MoodPeek.swift`:

| Constant | Value | Reason |
| --- | --- | --- |
| `box` | 160 pt | The picture's longest side; about Windows' 250 px at 150 % |
| `inset` | 24 pt | From the pane's left edge to the picture's; Windows' `PEEK_X` |
| `margin` | 12 pt | Between the peek's top and the usable area's top |
| `maxReserve` | 0.30 | The peek never takes more than 30 % of the usable height |
| `artAlpha` | 24 | Art means alpha > 24, the rule the shipped set is framed with |
| `maxSide` | 1024 px | Imported pictures are scaled down to this |

### 2. Count, mood and share

```swift
// PeekController
let n = Windows.list.lazy.filter { $0.shouldShowTheUser && !$0.isWindowlessApp }.count
```

- `shouldShowTheUser` includes scrolled-out tiles, counts a tab group once, and ignores the search query, so typing a search never changes the mood.
- `mood(n)`: nil for n ≤ 0, `.few` for n < `someFrom`, `.some` for n < `manyFrom`, otherwise `.many`.
- `share(n) = minShare + (maxShare - minShare) * clamp((n - 1) / (manyFrom + 3), 0, 1)`
- `MoodSettings.validated()`: an invalid threshold pair (outside `2 ≤ someFrom < manyFrom ≤ 30`) falls back to 3 and 8. An invalid share pair (outside `0.30 ≤ minShare < maxShare ≤ 1.00`) falls back to 0.80 and 0.95.
- The UI's clamping rules are pure functions here too, so they can be tested:
  - `settingSomeFrom(_:)` pushes `manyFrom` up to at least `someFrom + 1`, capped at 30.
  - `settingMinShare(_:)` pushes `maxShare` to at least `minShare + 0.01`, capped at 1.00.
  - The mirror functions do the reverse.

### 3. Picture metrics

A loaded picture is `PeekPicture { image: CGImage, pixelWidth, pixelHeight, artTop, artBottom }`. Art rows are the first and last rows (exclusive end) with any alpha > 24. For box scale `s`:

```text
k        = box * s / max(pixelWidth, pixelHeight)              // points per pixel
size     = (pixelWidth * k, pixelHeight * k)
up(n)    = (artTop + (artBottom - artTop) * share(n)) * k      // points shown above the pane
reserve  = max over the three moods of up at maxShare         // proportional to s
s        = min(1, maxReserve * visibleFrame.height / reserve(at s = 1))
```

### 4. Pane cap and placement

`V` is `screen.visibleFrame`, which excludes the menu bar and Dock. `R` is `reserve`. All values are in points; the backing scale applies only to the image layer's `contentsScale`.

- **Cap.** `TilesPanel.maxThumbnailsHeight` returns `min(<upstream expression>, (V.height - R - 2 * margin - 2 * Appearance.windowPadding).rounded())`. Overflowing tiles keep upstream's scrolling.
- **Placement.** This replaces `repositionPanel` for the pane only; other windows still use upstream's.
  - `x` is centred as upstream.
  - `y = min(V.minY + max(V.height - H, 0) / 2, V.maxY - margin - R - H)`, where `H` is the pane's height. Short panes stay centred; tall ones move down just enough.
- **Peek frame.** `(pane.minX + inset, pane.maxY, size.width, up(n))`, hidden when `up(n) < 1`.
- **Image layer.** Inside the peek panel's layer-backed content view (`masksToBounds = true`), the image layer's frame is `(0, up(n) - size.height, size.width, size.height)`. So the picture's top rows show, and the rest is clipped at the pane's edge, never drawn over the pane's material.
- **Stability.** `R` depends on the pictures, the settings and the screen, not on `n`. So a window closing while the switcher is open changes only the peek's height. The pane is still placed by upstream's rule in the room left.

### 5. Panel and hooks

`PeekPanel` copies `SearchDiscoveryPanel.swift:16-26`:

- `.nonactivatingPanel` with `isFloatingPanel` and `hidesOnDeactivate = false`
- clear and non-opaque, `animationBehavior = .none`
- `collectionBehavior = [.transient, .fullScreenAuxiliary, .ignoresCycle]`
- accessibility subrole `.unknown`, which also keeps it out of AltTab's own window list

It adds:

- `ignoresMouseEvents = true`
- `canBecomeKey` and `canBecomeMain` return false
- `hasShadow = false`
- `setAccessibilityElement(false)`

One panel is created in `setUp()` and reused.

Upstream edits are one line each, marked `// MeowTab:`.

| Where | Edit |
| --- | --- |
| `App.swift:527`, after `_ = TilesPanel()` | `PeekController.setUp()` removes orphans, loads pictures and creates the panel |
| `TilesPanel.updateContents`, after `repositionOrFreeze()` (`:56`), inside the transaction | `PeekController.update(paneFrame: frame, screen: NSScreen.preferred)` |
| `TilesPanel.repositionOrFreeze` `:67` and `:72` | `NSScreen.preferred.repositionPanel(self)` → `PeekController.positionPane(self, on: NSScreen.preferred)` |
| `TilesPanel.orderOut`, first line after `MainThreadStall.step()` (`:86`) | `PeekController.hide()`, before upstream's fade, so the picture never lingers |
| `TilesPanel.show()`, after `makeKeyAndOrderFront(nil)` (`:117`) | `PeekController.show()`: set `level = TilesPanel.shared.level`, `addChildWindow(panel, ordered: .above)` when there is a mood |
| `TilesPanel.maxThumbnailsHeight` (`:145`) | wrap in `min(…, PeekController.maxContentHeight(screen))` |

Behaviour of the controller:

- **`update`** stores `n`, the mood and the frames. It skips all work when `n`, the pane frame, the screen and the settings generation are unchanged, which is the case for selection steps. Otherwise it:
  - swaps the image layer's contents only when the mood changed;
  - sets the panel frame;
  - orders the panel out when the mood is nil.
- **Synchronous by design.** Everything runs on the main thread, inside upstream's call stack. No timer or async work exists, so a dismissed session can't leave work behind.
- **Permission loss** restarts the process (`App.restart()`), which takes the panel with it.
- **Timing log.** `update` measures itself with `os.Logger(subsystem: "io.github.tingtmu.meowtab.macos", category: "peek")` at `.debug`, as `update <ms> ms n=<n>`. The acceptance run reads it with `log stream --level debug --predicate 'category == "peek"'`.

### 6. PNG import, in this order

`PeekPicture.load(url:) throws` performs these steps, and stops at the first failure:

1. File size ≤ 10 MiB (`FileManager` attributes), else `.tooBig`.
2. `CGImageSourceCreateWithURL(url, [kCGImageSourceShouldCache: false])`, else `.unreadable`.
3. `CGImageSourceGetType` is `public.png`, else `.notPNG`. GIF, JPEG or a renamed file fail here.
4. `CGImageSourceGetCount` is 1, else `.animated`. ImageIO counts an APNG's frames. If the test in decision 9 shows it doesn't, scan for an `acTL` chunk before the first `IDAT` instead.
5. `CGImageSourceCopyPropertiesAtIndex`: width and height ≤ 8192 and width × height ≤ 32,000,000, else `.tooLarge`. No pixel has been decoded yet.
6. Decode:
   - longest side > 1024: `CGImageSourceCreateThumbnailAtIndex` with `FromImageAlways`, `ThumbnailMaxPixelSize: 1024` and `WithTransform`;
   - otherwise: `CGImageSourceCreateImageAtIndex`.

   Failure gives `.unreadable`.
7. Redraw into an sRGB, 8-bit, premultiplied-last `CGContext`, giving one pixel layout for scanning and saving.
8. Art span: scan rows for alpha > 24. If none qualify, `.empty`.

Saving uses `CGImageDestination` (PNG). The shipped pictures load through the same function at startup.

Import from the settings panel runs on a `.userInitiated` queue, with the result applied on the main thread.

The user-facing messages:

| Error | Message |
| --- | --- |
| `.tooBig` | "That file is over 10 MB." |
| `.notPNG` | "Choose a PNG picture. GIFs and other formats aren't supported yet." |
| `.animated` | "Animated PNGs aren't supported yet. Choose a still PNG." |
| `.tooLarge` | "That picture is too large (at most 8192 px a side and 32 megapixels)." |
| `.unreadable` | "That file can't be read as a picture." |
| `.empty` | "That picture is fully transparent." |

### 7. Storage

`MeowTabStore(defaults: .standard, folder: <Application Support>/MeowTab/images)` keeps its own keys and does not join upstream's `Preferences.defaultValues`, which keeps upstream merges simple.

| Key | Type | Default |
| --- | --- | --- |
| `meowtab.someFrom`, `meowtab.manyFrom` | Int | 3, 8 |
| `meowtab.minShare`, `meowtab.maxShare` | Double | 0.80, 0.95 |
| `meowtab.picture.few`, `.some`, `.many` | String (file name) | absent, meaning the shipped picture |

- **Setting a picture.** Write `<mood>-<UUID>.png` with `.atomic`. Only then set the key, then delete the old file. If anything fails before the key is set, the old picture stays in use.
- **Use default** removes the key and deletes the file.
- **Restore defaults** removes all `meowtab.*` keys and deletes MeowTab's picture files. It never touches anything else in the folder.
- **Orphans.** `removeOrphans()` runs at `setUp`. It deletes only files matching `^(few|some|many)-[0-9A-F-]{36}\.png$` that no key references.
- **Fallback.** `PeekController.reload()` loads each saved picture through `PeekPicture.load`. If one fails, the mood falls back to the shipped picture and the failure is kept as a warning: "Your picture for “some” couldn't be loaded, so the default cat is shown." The settings section shows it, and it is logged. An invalid stored setting falls back the same way, with "Some saved MeowTab settings were invalid and were reset."
- Settings-only changes reuse the decoded pictures; only a picture change re-decodes.

### 8. The MeowTab settings section

- **Registration.** `SettingsSectionDefinition(id: "meowtab", title: "MeowTab", symbol: .circledStar, builder: MeowTabSettingsTab.initTab, registerDynamicSearchContent: nil)` is the first entry of `sectionDefinitions()`. `MeowTabSettingsTab.cleanup()` is added to both cleanup lists. `.circledStar` is an existing glyph, which avoids regenerating the font subset. Being first, MeowTab is also the section Settings opens on (it selects `visibleSections[0]` by default, `SettingsWindow.swift:1191` at the baseline's HEAD); that is intended. Onboarding opens Appearance by its id, so it is unaffected.
- **Layout.** Rows built like `GeneralTab`'s:
  1. **Pictures.** Three `PictureCard` views, one per mood. Each has:
     - a 96×96 `NSImageView` that accepts `.fileURL` drops;
     - a title such as "Few · 1–2 windows", updated live from the thresholds;
     - "Choose…", which opens an `NSOpenPanel` with `allowedContentTypes = [.png]` (macOS 11+);
     - "Use default", shown only for a custom picture.
  2. **Moods.** "Some from" and "Many from", each an `NSStepper` with a value label, using the clamping rules of decision 2.
  3. **Peek height.** "With 1 window" and "With many windows", each an `NSSlider` from 30 to 100 in whole percent with a value label, using the same clamping rules.
  4. **Restore defaults** button, and a message line in `secondaryLabelColor` (`systemRed` for errors).
- **Applying changes.** Every change saves at once and calls `PeekController.reload(...)`, matching AltTab's apply-immediately settings. The switcher can't be open while the settings window has focus, so a session never sees a half-applied change.
- **Accessibility.** Every control has an accessibility label.
- **Strings.** All use `NSLocalizedString` with English keys and no translations; the other 20 languages fall back to English.

### 9. Tests (run on all three CI runners)

All fixtures are generated at runtime into a fresh folder under `FileManager.default.temporaryDirectory`, using `CGContext` and `CGImageDestination`. No binary fixtures are committed.

- **`MoodPeekTests`:**
  - moods for 0, 1, 2, 3, 7, 8, 12 and 20 windows with defaults;
  - custom thresholds 2 and 4 for counts 1, 2 and 4;
  - share at 1, 6, 12 and 20 windows (0.80, 0.80 + 0.15 × 5/11, 0.95, 0.95);
  - each invalid pair falls back;
  - the clamping rules;
  - `up(n)` for a 512² picture with art rows 200–312;
  - `reserve` is the maximum of the three moods;
  - `s = 1` and `reserve ≤ 0.30 × 600` for a 600-pt usable height, since a 160-pt box never needs more than 160 pt; `s < 1` and `reserve = 0.30 × 400` for a 400-pt one;
  - the pane cap;
  - pane `y` for a short and a tall pane;
  - peek frame bottom = pane top, `x` = pane `minX` + 24.
- **`PeekPictureTests`:**
  - a 512² transparent PNG with padding is accepted with the right span (±1 row);
  - 2000×1000 becomes 1024×512 with a transparent corner kept;
  - a JPEG renamed `.png` gives `.notPNG`;
  - a GIF gives `.notPNG`;
  - a two-frame APNG written with `kCGImagePropertyAPNGDelayTime` gives `.animated`;
  - the first 100 bytes of a PNG give `.unreadable`;
  - 10 MiB + 1 byte of filler named `.png` gives `.tooBig`;
  - 8200×4 gives `.tooLarge`;
  - a fully transparent PNG gives `.empty`.
- **`MeowTabStoreTests`:**
  - uses an isolated `UserDefaults(suiteName: "meowtab-tests-<uuid>")` and folder, removed in `tearDown`;
  - empty storage gives the defaults;
  - invalid stored values give the defaults plus a warning;
  - setting a picture writes the file before the key;
  - with the folder made read-only (`0o500`), setting fails and the previous key and file survive;
  - deleting the import source doesn't affect reload;
  - "Use default" and "Restore defaults" remove only MeowTab's files;
  - orphan removal spares files that don't match the pattern.

### 10. Adding files to `project.pbxproj` without Xcode

Hand-edit the file and copy existing entries:

- **Files in both targets:** copy `SearchDiscoveryPanel.swift`'s four kinds of entry: `PBXFileReference`, two `PBXBuildFile`s, the group child, and the two Sources phases (app `D04BAD01F4BCEDF8B539AFD2`, unit-tests `BF0C80F58922E3C39A30CC58`). `Screens.swift` is app-only, so it is not a template for these.
- **App-only files:** copy an app-only file such as `TilesPanel.swift`.
- **Pictures:** copy `app.png` in the Resources phase.
- **Group:** add a `meowtab` group under the `src` group.
- **IDs:** each new object needs a unique 24-digit uppercase hex ID, for example from PowerShell: `-join (1..24 | % { '{0:X}' -f (Get-Random -Max 16) })`.

Do all of this once, in task 1.1, with stub files, so a broken project file is found while the diff is small.

### 11. Optional: a CI screenshot of the peek

A time-boxed spike, worth trying because it would give visual evidence on every pull request without a Mac. Runner images write `TCC.db` at build time, which is why it is plausible, but it is unproven on arm64 `macos-15`/`macos-26`. Steps:

1. Log `csrutil status` and the `access` table schema.
2. Insert Accessibility and ScreenCapture grants for `io.github.tingtmu.meowtab.macos`.
3. Launch the app and open three TextEdit windows.
4. Run `/Applications/MeowTab.app/Contents/MacOS/MeowTab --show=0` (upstream's CLI, `CliEvents.swift:560`).
5. `screencapture -x` the screen and upload the image.

If it doesn't work within the time box, record what failed and rely on acceptance.

## Risks / Trade-offs

- **The peek's ordering in fullscreen Spaces and across displays isn't testable on CI** → Follows the codebase's own attached-panel precedent (`SearchDiscoveryHint`). Fullscreen, display and scale cases are listed for acceptance.
- **ImageIO may not report APNG frames as expected** → The test exposes it on CI, and decision 6 names the fallback.
- **`TilesPanel.updateMaxPossibleThumbnailSize` may be stale after a picture change shifts the cap** → The capture buffer is at most a little larger than needed. Accepted.
- **Hand-edited project file** → Done once, with stubs (task 1.1). Later tasks don't touch it.
- **Picture work in Settings blocks the UI** → Import runs off the main thread, and output is capped at 1024 px.
