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
- **Shipped pictures:** 512×512, where "art" means alpha > 24 (`openspec/specs/mood-pictures/spec.md` there). Each cat's art spans 483–484 px on its longer side. Measured here: few's art is rows 51–460 (410 tall, 484 wide), some's rows 112–399 (288 tall, 484 wide), and many's rows 14–496 (483 tall, 472 wide).

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
| `inset` | 24 pt | The least from the pane's left edge to the picture's, and from the picture's right edge to the pane's; Windows' `PEEK_X`. A larger corner radius takes over (decision 4) |
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
- **Peek frame.** `(pane.minX + side, pane.maxY, size.width * fit, up(n) * fit)`, hidden when `up(n) * fit < 1`, which includes a pane with no room between the two margins (`fit` is 0).
  - `side = max(inset, cornerRadius)`, where `cornerRadius` is upstream's `Appearance.windowCornerRadius`: 23 pt on macOS 15 and earlier in every style; on macOS 26, 43 pt with thumbnails, 50, 55 or 75 pt with small, medium or large app icons, and 23 pt with titles.
  - On a pane narrower than the picture plus `side` at each end (app icons with one window, say), `fit = min(1, (pane.width - 2 * side) / size.width)` scales the picture down, so it ends `side` from the right edge. Otherwise `fit` is 1.
  - So the cut edge lies on the straight part of the pane's top edge, with no gap under the cat where the corner curves away, and a narrow pane gets a smaller cat rather than one hanging off its edge.
- **Image layer.** Inside the peek panel's layer-backed content view (`masksToBounds = true`), the image layer's frame is `(0, up(n) - size.height, size.width, size.height)`, with `size` and `up(n)` both scaled by `fit`. So the picture's top rows show, and the rest is clipped at the pane's edge, never drawn over the pane's material.
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
| `App.showUiOrCycleSelection`, after `TilesPanel.shared.alphaValue = 0` (`App.swift:416`) | `PeekController.hide()`. A summon with another shortcut masks the pane at alpha 0 while it rebuilds, through the display delay (100 ms by default); without this, the attached picture would stay on screen with no pane under it. `show()` brings it back. Upstream cancels its search hint on the same path. |
| `TilesPanel.updateContents`, after `repositionOrFreeze()` (`:56`), inside the transaction | `PeekController.update(paneFrame: frame, screen: NSScreen.preferred)` |
| `TilesPanel.repositionOrFreeze` `:67` and `:72` | `NSScreen.preferred.repositionPanel(self)` → `PeekController.positionPane(self, on: NSScreen.preferred)` |
| `TilesPanel.orderOut`, first line after `MainThreadStall.step()` (`:86`) | `PeekController.hide()`, before upstream's fade, so the picture never lingers |
| `TilesPanel.show()`, after `makeKeyAndOrderFront(nil)` (`:117`) | `PeekController.show()`: set `level = TilesPanel.shared.level`, `addChildWindow(panel, ordered: .above)` when there is a mood |
| `TilesPanel.maxThumbnailsHeight` (`:145`) | wrap in `min(…, PeekController.maxContentHeight(screen))` |
| `SearchDiscoveryHint.prepareFrame` (`SearchDiscoveryHint.swift:162`) | `obstruction:` becomes `preview?.isVisible == true ? preview?.frame : PeekController.attachedFrame`, the peek panel's frame while it is attached to the pane. The search hint's first place is just above the pane, in the peek's room, so it would cover the picture whenever it shows; it needs 8 windows, so the peek is always up then. With the peek as the obstruction, upstream's policy moves the hint below the pane, and only when the two would overlap. Previews are off by default; while one shows, it stays the obstruction. |

Behaviour of the controller:

- **`update`** stores `n`, the mood and the frames. It skips all work when `n`, the pane frame, the corner radius, the screen and the settings generation are unchanged, which is the case for selection steps. Otherwise it:
  - swaps the image layer's contents when the mood or the pictures changed, not only the mood: each `reload` bumps a generation, and a new generation swaps them;
  - sets the panel frame;
  - orders the panel out when the mood is nil.
- **Synchronous by design.** Everything runs on the main thread, inside upstream's call stack. No timer or async work exists, so a dismissed session can't leave work behind.
- **A reload waits for an open switcher.** An import runs in the background, so it can finish after the switcher has opened. Its file is saved at once, but what follows (`pictureChanged`: the peek's reload, the cards and the message line) goes through `PeekController.whenSwitcherCloses`, which runs it at once when no switcher is open, and otherwise holds it for `hide()` at the session's end. The open session keeps its pictures and its reserved room, and the next session shows the new picture. `hide()` can tell a session's end because `App.beginHideUi` clears `SwitcherSession.current` before `TilesPanel.orderOut` calls it, so no session is open by then; the call that masks the pane for a cross-shortcut rebuild comes with the session open, and runs nothing.
- **Permission loss** restarts the process (`App.restart()`), which takes the panel with it.
- **Timing log.** `update` measures itself with `os.Logger(subsystem: "io.github.tingtmu.meowtab.macos", category: "peek")` at `.debug`, as `update <ms> ms n=<n>`. The acceptance run reads it with `log stream --level debug --predicate 'category == "peek"'`.

### 6. PNG import, in this order

`PeekPicture.load(url:) throws` performs these steps, and stops at the first failure:

1. File size ≤ 10 MB (10,000,000 bytes, as Finder counts; `FileManager` attributes), else `.tooBig`.
2. `CGImageSourceCreateWithURL(url, [kCGImageSourceShouldCache: false])`, else `.unreadable`.
3. `CGImageSourceGetType` is `public.png`, else `.notPNG`. GIF, JPEG or a renamed file fail here.
4. `CGImageSourceGetCount` is 1: more gives `.animated`, and 0 (a truncated file can report no images) gives `.unreadable`. ImageIO counts an APNG's frames. If the test in decision 9 shows it doesn't, scan for an `acTL` chunk before the first `IDAT` instead.
5. `CGImageSourceCopyPropertiesAtIndex`: width and height ≤ 8192 and width × height ≤ 32,000,000, else `.tooLarge`. No pixel has been decoded yet.
6. Decode, once the file contains PNG's `IEND` chunk (anywhere in it, so trailing bytes pass): a cut-short PNG can still decode into a partly blank picture, and ImageIO's frame status isn't reliable for a still image's only frame, so a missing `IEND` gives `.unreadable` first.
   - longest side > 1024: `CGImageSourceCreateThumbnailAtIndex` with `FromImageAlways`, `ThumbnailMaxPixelSize: 1024` and `WithTransform`;
   - otherwise: `CGImageSourceCreateImageAtIndex`.

   Failure gives `.unreadable`.
7. Redraw into an sRGB, 8-bit, premultiplied-last `CGContext`, giving one pixel layout for scanning and saving.
8. Art span: scan rows for alpha > 24. If none qualify, `.empty`.

Saving uses `CGImageDestination` (PNG). The shipped pictures load through the same function at startup.

Import from the settings panel runs on a `.userInitiated` queue, with the result applied on the main thread. The file is saved at once; if a switcher is open by then, the peek's reload waits for it to close (decision 5). The message line shows an error in red at once, and after a success the warnings still current (decision 8).

The user-facing messages:

| Error | Message |
| --- | --- |
| `.tooBig` | "That file is over 10 MB." |
| `.notPNG` | "Choose a PNG picture. GIFs and other formats aren't supported yet." |
| `.animated` | "Animated PNGs aren't supported yet. Choose a still PNG." |
| `.tooLarge` | "That picture is too large (at most 8192 px a side and 32 megapixels)." |
| `.unreadable` | "That file can't be read as a picture." |
| `.empty` | "That picture has no visible pixels." |

### 7. Storage

`MeowTabStore(defaults: .standard, folder: <Application Support>/MeowTab/images)` keeps its own keys and does not join upstream's `Preferences.defaultValues`, which keeps upstream merges simple.

| Key | Type | Default |
| --- | --- | --- |
| `meowtab.someFrom`, `meowtab.manyFrom` | Int | 3, 8 |
| `meowtab.minShare`, `meowtab.maxShare` | Double | 0.80, 0.95 |
| `meowtab.picture.few`, `.some`, `.many` | String (file name) | absent, meaning the shipped picture |

- **Setting a picture.** Write `<mood>-<UUID>.png` with `.atomic`. Only then set the key, then delete the old file. If anything fails before the key is set, the old picture stays in use.
- **Use default** removes the key, and deletes a file only if the key names one of MeowTab's own `<mood>-<UUID>.png` files. A value MeowTab can't use, such as a hand-edited `../x.png`, is removed and never treated as a path.
- **Restore defaults** removes all `meowtab.*` keys and deletes MeowTab's picture files. It never touches anything else in the folder.
- **Orphans.** `removeOrphans()` runs at `setUp`. It deletes only files matching `^(few|some|many)-[0-9A-F-]{36}\.png$` that no key references.
- **Fallback.** `PeekController.reload()` loads each saved picture through `PeekPicture.load`. If one fails, the mood falls back to the shipped picture and the failure is kept as a warning: "Your picture for “some” couldn't be loaded, so the default cat is shown." The settings section shows it, and it is logged. An invalid stored setting falls back the same way, with "Some saved MeowTab settings were invalid, so their defaults are used." A picture key that isn't one of MeowTab's own file names counts as invalid too. `load()` never writes, so a bad value stays saved and the message returns at each launch, until the value is replaced: moving a control saves all four settings, Use default drops a picture key, and Restore defaults drops every key.
- Settings-only changes reuse the decoded pictures; only a picture change re-decodes.

### 8. The MeowTab settings section

- **Registration.** `SettingsSectionDefinition(id: "meowtab", title: "MeowTab", symbol: .circledStar, builder: MeowTabSettingsTab.initTab, registerDynamicSearchContent: nil)` is the first entry of `sectionDefinitions()`. `MeowTabSettingsTab.cleanup()` is added to both cleanup lists. `.circledStar` is an existing glyph, which avoids regenerating the font subset. Being first, MeowTab is also the section Settings opens on (it selects `visibleSections[0]` by default, `SettingsWindow.swift:1191` at the baseline's HEAD); that is intended. Onboarding opens Appearance by its id, so it is unaffected.
- **Layout.** Rows built like `GeneralTab`'s:
  1. **Pictures.** Three `PictureCard` views, one per mood. Each has:
     - a 96×96 `NSImageView` that never registers for drags, so a drop on the picture reaches the card, which takes `.fileURL` drops anywhere on it;
     - a title such as "Few · 1–2 windows", updated live from the thresholds;
     - "Choose…", which opens an `NSOpenPanel` with `allowedContentTypes = [.png]` (macOS 11+);
     - "Use default", shown whenever the mood's `meowtab.picture.<mood>` key holds anything, even a value MeowTab can't use.
  2. **Moods.** "Some from" and "Many from", each an `NSStepper` with a value label, using the clamping rules of decision 2.
  3. **Peek height.** "With 1 window" and "With many windows", each an `NSSlider` from 30 to 100 in whole percent with a value label, using the same clamping rules.
  4. **Restore defaults** button, and a message line in `secondaryLabelColor` (`systemRed` for errors).
- **Applying changes.** Every change saves at once and calls `PeekController.reload(...)`, matching AltTab's apply-immediately settings. The switcher can't be open while the settings window has focus, so a session never sees a half-applied change. An import is the one change that can arrive while a session is open, because it finishes in the background; what follows its save waits for the session to end (decision 5).
- **Message line.** An import error shows in red. After a control moves, or a picture is saved or cleared, the line shows the warnings still current after the reload, and is empty if there are none, instead of keeping or clearing whatever it showed. So an old error goes, and a warning that still applies, such as an unusable picture key, stays.
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
  - peek frame bottom = pane top, `x` = pane `minX` + 24;
  - a 43-pt corner puts `x` at pane `minX` + 43 with the same size, and a 23-pt corner keeps 24;
  - a 132-pt pane with 23-pt corners scales the peek and its image by 84/160, so the peek ends 24 pt from the pane's right edge;
  - a pane no wider than its two margins has no peek.
- **`PeekPictureTests`:**
  - a 512² transparent PNG with padding is accepted with the right span (±1 row);
  - 2000×1000 becomes 1024×512 with a transparent corner kept;
  - a JPEG renamed `.png` gives `.notPNG`;
  - a GIF gives `.notPNG`;
  - a two-frame APNG written with `kCGImagePropertyAPNGDelayTime` gives `.animated`;
  - the first 100 bytes of a PNG give `.unreadable`;
  - 10 MB + 1 byte (10,000,001 bytes) of filler named `.png` gives `.tooBig`;
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
  - a hand-edited picture value (a path or a number) warns at every load and still offers Use default, which removes the key and deletes no file;
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
- **`TilesPanel.maxPossibleThumbnailSize` may go stale when a picture or setting change shifts the cap** → `PeekController.reload` calls `TilesPanel.updateMaxPossibleThumbnailSize()`, so thumbnail captures follow a changed reserve at once. Launch is the exception: upstream sizes them before `setUp` creates the panel, and `setUp`'s own reload leaves them alone, so until the first later reload or upstream's own reset a capture is at most a little larger than needed. Accepted.
- **Smaller tiles** → With thumbnails, the pane's cap lowers `maxThumbnailsHeight`, which upstream divides by its row count to size every tile. So tiles shrink whenever the usable height minus the reserve and the margins falls below upstream's cap, even with few windows: on a 1440×900 display with the Dock showing (usable height about 805 pt), the cap falls from 684 to 597 pt on macOS 15, so tiles are about 13 % smaller. A reserve that followed the count would instead resize the tiles as windows open and close. Accepted.
- **Hand-edited project file** → Done once, with stubs (task 1.1). Later tasks don't touch it.
- **Picture work in Settings blocks the UI** → Import runs off the main thread, and output is capped at 1024 px.
