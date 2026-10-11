# MeowTab Mac roadmap

Where MeowTab Mac goes after its first MVP. Each item says what to build, why, and how we'll know it's done, so it can be picked up on its own without the history of earlier sessions.

**Today:** the MVP is planned as three OpenSpec changes, done in order. The first is done.

1. [mac-fork-baseline](openspec/changes/archive/2026-10-11-mac-fork-baseline/proposal.md) (done, 2026-10-11): the AltTab v11.9.0 fork, renamed, offline, Pro unlocked, and green on CI. Its specs are in `openspec/specs/`.
2. [mac-png-peek](openspec/changes/mac-png-peek/proposal.md): the peek with three static PNG moods and a MeowTab settings section.
3. [mac-preview-release](openspec/changes/mac-preview-release/proposal.md): stable signing, packages, the install guide, one real-Mac acceptance run, and the 0.1.0 preview.

AltTab's own features stay as upstream has them. GIF playback, background cleaning and trimming AltTab down are deferred.

**Order:** accept the complete Mac MVP first, then tackle items 1, 2, and 3 below. Item 4 can come at any point after the MVP. Each item becomes a separate OpenSpec change when it is picked up. These are future plans, not additions to the current MVP's acceptance requirements, and no release dates are committed.

**Principles**, in order, when they conflict:

1. **Fast and light first.** Opening the switcher and moving the selection must feel instant. Animation and image processing must earn their resource cost.
2. **Keep the familiar AltTab interface.** Add the mood-picture features in one small MeowTab settings section, not spread through AltTab's.
3. **The peek is the soul.** Intended visible artwork must fit above the pane and inside the display work area, including when it moves.
4. **Local and reversible.** Pictures stay on the device. Imports and cleaning preserve the user's originals, and a failed operation keeps the last working picture.
5. **Private demos.** Documentation screenshots and recordings use dedicated demo windows, a stand-in background, and isolated settings.

Planning map:
- [mood and peek behavior](openspec/changes/mac-png-peek/specs/mood-peek/spec.md)
- [picture import and settings](openspec/changes/mac-png-peek/specs/peek-settings/spec.md)
- [releases and acceptance](openspec/changes/mac-preview-release/specs/mac-release/spec.md)

Once a change is archived, its specs live in `openspec/specs/`. Later picture work should build on the picture-loading code in `src/meowtab/PeekPicture.swift`; the Windows version is a behavior reference.

---

## 1. Animated GIF mood pictures

**Why:** users should be able to give each mood an animated picture, as they can in Windows MeowTab.

**Today:** the MVP accepts static PNGs only. Its shipped PNG cats remain the default when GIF support arrives.

**Plan:**

- Accept a GIF chosen for or dropped onto any of the three mood cards. Save an app-managed copy so moving or deleting the source file does not break the picture. Existing PNG choices continue to work.
- Play the GIF in the peek and visible settings previews. Respect frame delays, loop information, transparency, and frame disposal; restart on a new switcher session or a change to another mood, without restarting on every selection step.
- Follow macOS Reduce Motion: show a still first frame when it is enabled. Stop animation work when its switcher or preview is hidden, and prevent delayed work from reviving a dismissed picture.
- Use stable artwork bounds across the composited frames. The pane must not move as the animation changes, and moving artwork must still fit within the reserved peek area.
- Bound import size, dimensions, frame count, and decoded memory. Decide the exact limits and caching strategy in the GIF proposal after measuring representative files; do not decode every frame eagerly without a resource budget.
- Validate decoded content, reject corrupt or excessive inputs with a friendly explanation, and keep the prior saved picture on failure. Keep decoding and file access out of repeated selection work.

**Done when:**

- All three moods can independently use PNGs or GIFs, and their choices survive relaunch and app replacement.
- Fixtures cover transparent frames, partial-frame updates, disposal modes, variable delays, finite/infinite loops, malformed files, and import limits.
- Reduce Motion, rapid dismissal/reopening, changing moods, and different display scales behave correctly.
- Repeated opens leave no accumulating animation resources, and hidden views leave no animation-specific recurring work.
- Mac measurements report startup/import cost, warm switching overhead, animation CPU, and peak/retained memory. A complete candidate passes final visual and switching checks on a real Mac.

## 2. Clean background for static pictures

**Why:** a user can turn a picture with a simple background into a natural peek without needing a separate image editor.

**Today:** the MVP preserves imported PNG transparency but does not remove backgrounds.

**Plan:**

- Add an optional **Clean background** action to a mood card. Start with simple, mostly uniform pale or solid backgrounds; complex photos and automatic subject segmentation are outside this first cleaning change.
- Process locally and show the result before it is saved. Preserve existing transparent areas and avoid removing subject details such as ears and whiskers.
- Keep the original imported picture available for restoring or retrying. Cancel, processing failure, or save failure leaves the last complete working selection unchanged.
- Store the cleaned result as a transparent PNG. Recalculate artwork bounds and preserve aspect ratio so cleaning does not undermine peek height or placement.
- Perform processing during picture editing, away from the switching path. Reuse import validation and resource limits rather than adding an online service.
- Evaluate the Windows cleaning algorithm and fixtures as references; choose the Mac implementation in the later proposal instead of assuming its Windows pipeline can be reused unchanged.

**Done when:**

- Users can preview, save, cancel, and restore a cleaned static picture through the MeowTab settings section.
- Representative fixtures cover pale backgrounds, colored backgrounds, existing alpha, thin details, and subjects whose colors resemble the background. Document cases the tool cannot clean reliably.
- The saved result looks correct on light and dark panes, with no unexpected opaque rectangle or cropped subject.
- Cancelled, failed, and interrupted operations preserve the working picture and original. Relaunch loads the complete saved result.
- A complete candidate passes automated checks and final real-Mac visual acceptance.

## 3. Clean background for animated GIFs

**Why:** animated custom moods should have the same clean peek as static pictures.

**Depends on:** GIF playback and static-picture cleaning being accepted first.

**Plan:**

- Extend **Clean background** to GIF imports. Clean composited frames with correct disposal handling, retaining frame order, timing, and loop behavior.
- Use one shared canvas and crop based on the animation's combined artwork bounds. Avoid frame-to-frame jumps in size or placement.
- Preserve the original GIF and preview the entire processed animation before saving. Make processing cancellable, report failures, and never replace a working picture with a partially written result.
- Budget processing time and memory separately from playback. Keep cleaning out of switcher sessions, and give long operations clear progress.
- Resolve output transparency in the proposal: GIF supports a transparent palette entry rather than full partial alpha. Choose and document the edge treatment; do not promise PNG-like soft transparency in GIF output.

**Done when:**

- A cleaned GIF retains its subject throughout the loop, timing, and stable placement in both the peek and settings preview.
- Fixtures cover changing background colors, partial frames, disposal modes, transparent frames, thin details, and content near canvas edges.
- Preview, Save, Cancel, restore-original, processing failure, and relaunch all preserve a complete working selection.
- Import and cleaning limits keep memory bounded, and no cleaning work runs during switching.
- The complete candidate passes automated checks and final real-Mac animation acceptance.

## 4. A focused switcher (trimming AltTab)

**Why:** the MVP keeps all of AltTab's features and settings, Pro features included, so that the fork changes as little as possible while nobody can test it on a Mac. The original idea was a simpler app: one shortcut, the thumbnail look, and only the settings MeowTab needs.

**Today:** AltTab's features are all there. Sparkle and AppCenter are linked but never started (see `mac-fork-baseline`).

**Plan:**

- Decide, from the tester's and users' feedback, which AltTab features to drop. Candidates are search, extra shortcut profiles, the app-icon and title styles, trackpad gestures, the command-line interface, the minimize/fullscreen/quit tile buttons and the full-size preview. Keep window discovery, permissions, Spaces, displays and closing windows.
- Remove each dropped feature at its entry points and settings in small steps, each green on CI, with upstream's tests for it removed alongside.
- Unlink the Sparkle and AppCenter packages: the project file, the Embed and Copy Sparkle Helpers phases, and the seven Swift files that import them.
- Remove the code `mac-fork-baseline` left inert: the Settings `upgradeButton` and its refresh and shine code, the menubar licence items and `UpgradeMenuItemView`, `App.upgradeToPro`, the `updatesPolicyDropdown` and `crashPolicyDropdown` statics, the Upgrade tab, `FeedbackWindow`, the licence client, and the strings only they use.
- Weigh the cost of merging later upstream releases. Every removal makes merges harder.

**Done when:** Settings shows only what is kept; no removed feature can be reached from the menubar, the shortcuts or the switcher; the app bundle has no Sparkle or AppCenter; and a real-Mac candidate passes the MVP's switching and peek checks again.

## Also on the list

- **Developer ID signing and notarization**, if the owner gets an Apple Developer account. Gatekeeper would then stop asking on first open, and permissions would be kept even across a certificate change.
- **A paw icon** for the MeowTab settings section, which needs the bundled SF Pro subset regenerated (`scripts/assets/subset_font.sh`).
- **The ten strings that still say "AltTab"**, worth fixing when their translations can be updated too.

---

## Performance and release checks for every later change

Use the accepted Mac MVP as the comparison baseline. Keep its switching behavior, permission handling, display/Spaces behavior, and user data intact.

The MVP's peek budget: each peek update logs its duration, and the median on the real Mac must be at most **1 ms** with about 10 windows, with the maximum reported. A selection step costs the peek only a comparison. No file is read or picture decoded while the switcher is open, and the peek has no timers. Later changes keep these rules and report their own measurements the same way. Animation adds its own CPU and memory measurements; stop its recurring work while hidden.

Build and run automated checks on GitHub macOS runners, then give the friend a complete candidate for final desktop acceptance. Record the tested macOS version and chip, plus any untested versions or hardware scenarios. A successful build alone does not establish runtime compatibility across the supported macOS range.

When an item is picked up, its OpenSpec proposal should settle the remaining limits and processing choices, update the affected specs, and turn these completion criteria into implementation tasks.
