# Proposal

Second of three changes: `mac-fork-baseline` → **mac-png-peek** → `mac-preview-release`. Starts after `mac-fork-baseline` is archived.

## Why

The peek is what makes MeowTab MeowTab: a picture sitting on the switcher's top-left edge that changes with how many windows are open. Windows MeowTab has it; the Mac fork so far is plain AltTab. This change adds the peek with the three shipped cat PNGs, and lets users choose their own PNG for each mood.

## What Changes

- **The peek.** A click-through picture sits on the AltTab pane's top-left edge, 24 pt in from the pane's left edge. Only the part above the pane's top edge shows. It appears with the pane and disappears with it. It never takes focus, clicks or keyboard input, and screen readers ignore it.
- **Three moods by window count**, with the same rules and defaults as Windows MeowTab:
  - few for 1–2 windows, some for 3–7, many for 8 or more;
  - "windows" means real windows the switcher lists, scrolled-out ones included; app-only placeholder tiles don't count;
  - with no real window, the picture hides.
- **Peek height.** 80 % of the picture's art shows above the pane with 1 window, rising evenly to 95 % at `manyFrom + 4` windows. Transparent padding is ignored.
- **It always fits.** The pane gives up vertical room so the tallest possible peek stays inside the display's usable area. The pane doesn't move when the count changes during an open switcher. The picture shrinks only on very short displays.
- **Static PNGs.** The three `chill_*.png` cats from Windows MeowTab ship in the app. There is no animation or GIF yet. No file is read and no picture decoded while the switcher is open.
- **A MeowTab section in Settings**, first in the sidebar. It has:
  - three picture cards (choose or drop a PNG; "Use default");
  - "some from" and "many from" steppers;
  - two peek-height sliders;
  - "Restore defaults";
  - a message line for import errors.

  Changes apply at once, like the rest of AltTab's settings.
- **Picture import.** PNG only (checked by content), up to 10 MB, 8192 px a side and 32 megapixels. Animated PNGs, GIFs, empty and corrupt files are refused with a reason, and the old picture stays. Accepted pictures are scaled to at most 1024 px. MeowTab keeps its own copy in `~/Library/Application Support/MeowTab/images/`, so moving or deleting the original changes nothing.
- **Out of scope:** GIF and animation, background cleaning, a slide-up motion, the peek preview scenes of Windows' settings panel, and a fourth mood.

## Capabilities

### New Capabilities

- `mood-peek`: window count, moods, peek height, placement and fitting, lifecycle, and cost.
- `peek-settings`: the MeowTab settings section, picture import and its limits, storage, defaults and fallbacks.

### Modified Capabilities

None.

## Impact

- **New files in `src/meowtab/`:**
  - `MoodPeek.swift`: pure mood and geometry logic;
  - `PeekPicture.swift`: PNG import and art span;
  - `MeowTabStore.swift`: settings and the picture folder;
  - `PeekPanel.swift`: panel and controller;
  - `MeowTabSettingsTab.swift`: settings UI;
  - tests next to them: `MoodPeekTests.swift`, `PeekPictureTests.swift`, `MeowTabStoreTests.swift`.
- **New resources:** `resources/meowtab/chill_few.png`, `chill_some.png` and `chill_many.png`, copied byte for byte from Windows MeowTab.
- **Upstream files, small hooks only:**
  - `src/App.swift`: one line after `_ = TilesPanel()` at :527;
  - `src/switcher/main-window/TilesPanel.swift`: `updateContents`, `repositionOrFreeze`, `orderOut`, `show`, `maxThumbnailsHeight`;
  - `src/preferences/settings-window/SettingsWindow.swift`: one section entry and two cleanup calls.
- **Project and docs:** `alt-tab-macos.xcodeproj/project.pbxproj` (new files, the group and build phases); `docs/acknowledgments.md` (the cat pictures' MIT notice); `README.md` (the peek and own pictures); `ROADMAP.md`.
