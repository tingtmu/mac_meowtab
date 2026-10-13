# Acceptance run sheet

The manual checks for MeowTab for Mac that CI cannot do. A tester with a Mac, or the owner on a GitHub-hosted macOS runner (see [On a GitHub-hosted runner](#on-a-github-hosted-runner)), works through the rows below on a release candidate, a GitHub pre-release such as `v0.1.0-rc.1`, installed as its `INSTALL.md` says.

## Run details

| Detail | Value |
|--------|-------|
| Environment: a Mac, or a GitHub-hosted runner over VNC (give its image, `macos-26` or `macos-15`) | |
| Date | |
| Candidate tag | |
| macOS version (run `sw_vers` in Terminal) | |
| Chip (Apple menu > About This Mac) | |
| Displays and their scales (System Settings > Displays; for example "built-in, Retina" or "external, not Retina") | |
| AltTab or another window switcher installed? Which? | |
| The Mac's language (System Settings > General > Language & Region; the rows quote the English labels) | |

## How to fill in the rows

For each row, do what the Notes column says, then fill in Result:

- **Pass**: the scenario's expected outcome happened.
- **Fail**: it did not. Say what happened instead in Notes.
- **Not tested — reason**: you did not check it. Give the reason after the dash, for example "Not tested — one display". "Not tested" never counts as a pass.

Work through the rows in order, since some rows build on earlier ones. From `rc.2` on, do row 40 first.

A window count in a row means the windows the switcher lists, and the Terminal window you run commands in is one of them. Close the other windows first, or read `n=` in the peek log (see row 22, "Measuring on a real Mac").

MeowTab and AltTab both open their switcher with ⌥⇥, so keep AltTab quit, except in row 11.

Whenever you put a new copy of MeowTab in Applications, macOS may block it the first time you open it. Open it as INSTALL.md step 3 says.

**Privacy.** Any screenshot you take for this run, or send with it, shows only demo windows, such as empty TextEdit or Finder windows, over a plain desktop picture. It never shows your real windows, window titles or files.

## On a GitHub-hosted runner

Skip this section on a Mac of your own. A runner is a virtual Mac on Apple silicon that you control from your computer over VNC.

- **Start a session.** In the repository's Actions tab, choose "Remote Mac session" > "Run workflow", or run `gh workflow run remote-mac.yml -R tingtmu/mac_meowtab --ref main -f image=macos-26 -f minutes=90`. The session lasts `minutes` (10 to 300); cancel the run to end it early. A runner starts fresh, with nothing installed, so do the whole run, through row 43, in one session.
- **Connect.** You need Tailscale on your computer, signed in to the owner's network, and a VNC viewer that asks only for a password, such as TigerVNC, set to pass special keys (or "system keys") to the Mac, so that Windows doesn't take Alt+Tab: Alt is ⌥ and the Windows key is ⌘. The job's "Show how to connect" step prints the address, the runner's Tailscale IP with port 5900. The VNC password is the first 8 characters of the `REMOTE_MAC_PASSWORD` secret. Check that ⌘⇥ (Windows key + Tab) opens macOS's app switcher, not Windows' Task View. When macOS asks for an administrator, at Open Anyway or when you turn a permission on, replace the user name it fills in with `meowtester` and enter the whole secret.
- **Download in Safari.** In the session, download the candidate's zip from its release page in Safari, so macOS marks it as downloaded from the internet, as it does for any user. Turn off Safari > Settings > General > "Open “safe” files after downloading" first, so the zip stays in Downloads. Before row 1, run `xattr -p com.apple.quarantine ~/Downloads/MeowTab-*.zip` in Terminal: it prints a value. If it prints nothing, mark row 1 "Not tested — no quarantine". If the job's log warned that Gatekeeper is off, mark row 1 "Not tested — Gatekeeper off".
- **Row 40.** From `rc.2` on, row 40 needs the previous candidate installed and granted earlier in the same session: download it in Safari too, install it with INSTALL.md steps 1 to 4, then do row 40. On `rc.1`, there is no earlier candidate, so mark the row as it says.
- **The VM note.** The runner is a VM with System Integrity Protection (SIP) off, so a pass on first open, permissions or updating is evidence, not proof that a stock Mac behaves the same. Start the Notes of rows 1, 2, 3 and 40 with "VM, SIP off". The other rows count fully.

## Rows

### 1. Install and permissions

| # | Spec | Scenario | Result | Notes |
|---|------|----------|--------|-------|
| 1 | mac-release | First open on macOS 26 | | Install MeowTab with INSTALL.md steps 1 and 2, then open it the first time with step 3, using only the guide: on macOS 15 and later through System Settings > Privacy & Security > Open Anyway, on macOS 14 and earlier with Control-click > Open. MeowTab opens with no Terminal command and shows its permissions window. Some of that window's text still says "AltTab": a known issue listed in the README, not a failure. In Notes, say which steps you followed, and anything in the guide that was unclear. |
| 2 | mac-release | Granting Accessibility | | Follow INSTALL.md step 4 to grant Accessibility. In MeowTab's permissions window, step 1 is Accessibility: click "Grant permission", follow macOS to System Settings > Privacy & Security > Accessibility, and turn MeowTab on. On macOS 27, MeowTab's window calls this permission "Device Control", and System Settings lists it as "Device Control and Data Access". MeowTab's window then moves on by itself to step 2, Screen Recording. |
| 3 | mac-release | Skipping Screen Recording | | Follow INSTALL.md step 4, skipping Screen Recording: in MeowTab's permissions window, click "Continue without thumbnails" (it warns "Windows will show as app icons"). The window closes. Open 3 TextEdit windows, then hold ⌥ (Option) and press ⇥ (Tab): each tile shows TextEdit's icon where a picture of its window would be. Release ⌥. Now grant it after all: click MeowTab's menubar icon, choose "Check permissions…", click "Grant permission" next to "Skipped" on the Screen Recording card, and turn MeowTab on in System Settings > Privacy & Security > Screen Recording (called Screen & System Audio Recording on recent macOS). If macOS offers to quit and reopen MeowTab, choose Later. Back in MeowTab's permissions window, click Close. Open the switcher again: within a second or two, the tiles show pictures of the windows. If they still show icons, quit MeowTab from its menubar icon, open it again and retry. Either way it's a pass if the pictures come back; say in Notes whether you had to reopen MeowTab. |

### 2. Switching basics

These check AltTab's own behaviour, which MeowTab keeps.

| # | Spec | Scenario | Result | Notes |
|---|------|----------|--------|-------|
| 4 | upstream | Switching with the keyboard and the mouse | | If AltTab is running, quit it first (INSTALL.md step 5). With 3 TextEdit windows open, hold ⌥ and press ⇥: the switcher opens with a tile selected. Still holding ⌥, press ⇥ again: the selection moves to the next tile. Press ⇧ (Shift): it moves back one tile. Release ⌥: the selected window comes to the front. Open the switcher again and press Esc: it closes, and the window that was in front stays in front. Open it again and, still holding ⌥, click another tile: that window comes to the front. |
| 5 | upstream | Closing a window with unsaved changes | | In TextEdit, make a new document (File > New) and type a few words; don't save it. Open the switcher and, still holding ⌥, select that document's tile and press W, or click the close button on its tile. TextEdit reacts as it does when you click the window's red close button: it asks whether to save the document, and the tile stays in the switcher. Release ⌥, bring the document to the front if it isn't, and click Cancel in TextEdit's question: the window is still open, with your text. Close the document afterwards without saving it. |

### 3. The fork, the peek and its settings

| # | Spec | Scenario | Result | Notes |
|---|------|----------|--------|-------|
| 6 | fork-identity | About window | | Open About from the menubar. It shows MeowTab and its version. "Source code" opens github.com/tingtmu/mac_meowtab and "Based on AltTab" opens github.com/lwouis/alt-tab-macos. There is no Website link. |
| 7 | fork-identity | Supporting the author from the app | | In the About window, click "Sponsor AltTab's author". The browser opens github.com/sponsors/lwouis. |
| 8 | offline-app | Weeks after installing | | Use MeowTab for more than 14 days after installing it. To check sooner: quit MeowTab, run `defaults write io.github.tingtmu.meowtab.macos.license trialStartDate -float $(( $(date +%s) - 20 * 86400 ))` in Terminal, then open MeowTab again and use it for a while. No trial countdown, upgrade window or upgrade popover appears at any point. In Settings > Controls, add another shortcut, give it a key, and open the switcher with it. Open the switcher, press S, release the keys, and type a few letters: the search filters the windows. Starting a search keeps the switcher open when you release the keys. Don't type before pressing S: while the switcher is open, W, M and F close, minimize or full-screen the selected window, and Q and H quit or hide its app. |
| 9 | offline-app | Settings window | | Open every section in the Settings sidebar (MeowTab, Appearance, Controls, General, Exceptions). The sidebar has no Upgrade entry, "Get Pro" or "Pro activated" button above Quit. Wherever a Pro badge appears, use the control next to it: in Appearance, pick the app-icon and title styles and Auto size; in Controls, add another shortcut, set a shortcut's "After keys are released" to Search, and in "Shortcuts when active…" record the Search shortcut. Each choice applies, and nothing opens an upgrade or account view. |
| 10 | offline-app | No traffic after permissions | | CI only checks the phase before permissions. Grant Accessibility (and Screen Recording if you like), then use MeowTab for at least 2 minutes: open the switcher several times, open Settings and About. Meanwhile, in Terminal, run `lsof -nP -a -i -p $(pgrep -x MeowTab)` a few times, or `nettop -P -L 1 -p $(pgrep -x MeowTab)`. Neither shows a connection at any point. Clicking a link in About opens the browser; that traffic is the browser's, not MeowTab's. |
| 11 | fork-identity | Both apps installed | | Install AltTab next to MeowTab and run both. Change a setting in MeowTab, then open AltTab's Settings: the same setting is unchanged there. In System Settings > Privacy & Security > Accessibility, AltTab and MeowTab each have their own entry. |
| 12 | mood-peek | Picture placement | | Open 1, then 3, then 8 TextEdit windows, and open the switcher each time: a cat sits on the pane's top-left edge, the few cat with 1–2 windows, some with 3–7 and many with 8 or more. To look closely, run `screencapture -T 5 ~/Desktop/peek.png` in Terminal, open the switcher within 5 seconds and hold it until the shot is taken, then zoom in. The cat is cut off exactly at the pane's top edge: no gap between them, and no part of the cat drawn over the pane. On macOS 15 and earlier, the picture starts 24 pt in from the pane's left edge; the cats have a little transparent margin, so their first visible pixels are about 28 pt in (few and some) or 30 pt (many), about 56 or 60 px on a Retina screenshot. On macOS 26 the picture starts where the corner's curve ends: 43 pt in with thumbnails, and 50, 55 or 75 pt with app icons of size "Small", "Medium" or "Large" (set it in Settings > Appearance > Size; "Auto" picks a size that fits), and still 24 pt with titles. The first visible pixels are again about 4 pt (few and some) or 6 pt (many) further in. Either way the cut edge lies on the straight part of the pane's top edge, with no gap under the cat at the curve. With app icons and a single window, the pane can be narrower than the cat plus its margins; then the cat is scaled down to fit, ending as far from the pane's right edge as it starts from the left. The cat's top stays at least 12 pt below the menu bar. Repeat with each style in Settings > Appearance (thumbnails, app icons and titles), and with app icons also with each size and with one window. |
| 13 | mood-peek | Scrolled grid with placeholders | | Keep `log stream --level debug --predicate 'category == "peek"'` running in Terminal. Open real windows until the switcher's grid has to scroll (about 15 to 20 on a laptop), and close every window of two other running apps, for example Preview and Safari, so they show as windowless tiles at the end. Open the switcher and scroll. With this many windows the pane is at its tallest: the grid scrolls instead of the pane growing, and the whole cat is on screen, its top at least 12 pt below the menu bar. The log's `n=` equals the number of real windows: scrolled-out tiles count, and the two windowless tiles don't. Then, in an app with exactly two windows open, choose Window > Merge All Windows and open the switcher again: `n=` drops by one, since a group of tabs counts once. |
| 14 | mood-peek | Typing a search | | With the log running and about 10 windows open (the many cat), open the switcher, press S, release the keys, and type a few letters that match only one or two windows. Don't type before pressing S: while the switcher is open, W, M and F close, minimize or full-screen the selected window, and Q and H quit or hide its app. The tiles narrow, but the cat stays the many cat at the same height on the pane's top-left edge, and the log's `n=` stays the same. Esc leaves the search, and a second Esc closes the switcher. |
| 15 | mood-peek | Only placeholders | | Keep `log stream --level debug --predicate 'category == "peek"'` running in Terminal. This row uses Shortcut 2, which exists by default: Option and the key above Tab, showing only the active app's windows. Check it in Settings > Controls > "Shortcut 2" > Filtering: "Show windows from applications" is "Active app", and "Show apps with no open window" is "Show at the end" (or "Show"), not "Hide". In TextEdit, close every window with ⌘W, so TextEdit is the active app with no window. Open the switcher with Shortcut 2: only TextEdit's windowless tile shows, no cat appears, and the log shows `n=0`. Release the keys on that tile: it does what it does in AltTab, bringing TextEdit to the front. The Terminal running `log stream` isn't listed, since only the active app's windows are. If the log shows `n=1`, TextEdit still has a window, such as an open-file panel: close it and try again. |
| 16 | mood-peek | A window closes while the switcher is open | | Open 3 windows (the some cat). Open the switcher, keep holding the shortcut, select one of the windows and press W (Close window), or click the close button on its tile. The cat changes to few at once and sits on the pane's new top edge, with no gap or overlap, and no part of it goes above the usable area. Do the same with 8 windows (many): after the close, the some cat shows. |
| 17 | mood-peek | Cancel and reopen quickly | | In Settings > Appearance > Animations…, turn on "Fade out animation of Switcher". With 3 windows open, open the switcher, press Esc, and reopen it at once, while the pane is still fading. The cat disappears the moment you press Esc, without waiting for the fade; the reopened switcher shows its own cat on its pane's edge, and no old picture is left anywhere. Repeat a few times, then once more with the fade turned off. |
| 18 | mood-peek | Clicking where the picture is | | With a window behind where the cat appears, open the switcher and click on the cat. The click does what a click on any spot outside the pane does: the switcher closes without switching. The cat never takes the click: the window behind it doesn't come forward, and MeowTab doesn't become the active app. |
| 19 | mood-peek | VoiceOver | | Turn on VoiceOver (⌘F5). Open the switcher and move through it with the arrow keys and with VoiceOver's own keys (Control-Option and the arrows). VoiceOver reads the tiles and never lands on or announces the cat, and no tile in the switcher is the cat itself. Turn VoiceOver off afterwards (⌘F5). |
| 20 | mood-peek | Two displays with different scales | | Connect a non-Retina display next to a Retina one, and set Settings > Appearance > "Show on" to "Screen including mouse". Open the switcher with the pointer on each display in turn. Each time the cat is sharp, with a smooth outline and no blur, and sits on that pane's top-left edge with no gap or overlap. With one display only, mark this row "Not tested — one display"; with two displays but no non-Retina one, "Not tested — no non-Retina display". |
| 21 | mood-peek | Fullscreen Space | | Put an app into full screen (the green button) and open the switcher from its Space. The cat shows on the pane's top edge there and disappears with the pane. Switch to another Space and back: no picture is left behind on any Space. |
| 22 | mood-peek | Measuring on a real Mac | | In Terminal, run `log stream --level debug --predicate 'category == "peek"'`. With about 10 windows open, open the switcher 20 times, releasing it or pressing Esc each time. Each opening logs at least one line `update <ms> ms n=<n>`, where n is the number of windows. Paste the output into the Timing section below, with the median and the maximum of the times: the median is at most 1 ms. Then open the switcher once more and hold it. After a second or two, once the thumbnails have loaded, move the selection several times with the arrow keys or by pressing the shortcut's key again: no new `update` line is logged, and the cat and its height don't change. |
| 23 | mood-peek | Summon with another shortcut | | Shortcut 2 exists by default and uses the same hold key as Shortcut 1: Option, with the key above Tab, showing only the active app's windows (see Settings > Controls). Open 3 TextEdit windows and keep TextEdit active. In Settings > Appearance > Animations…, set "Apparition delay of Switcher" to 900 ms so the switch is easy to watch. Open the switcher with Option-Tab and, still holding Option, press the key above Tab. While the pane is hidden for the rebuild, the cat is hidden too: it is never on screen without the pane under it. Then it comes back on the new pane's edge. Set the delay back to 100 ms afterwards. |
| 24 | mood-peek | Search hint and the peek | | The search hint shows at most 3 times, 72 hours apart, and never after the first search, so reset it first: quit MeowTab, run `defaults delete io.github.tingtmu.meowtab.macos.usage searches; defaults delete io.github.tingtmu.meowtab.macos searchDiscovery.exposures; defaults delete io.github.tingtmu.meowtab.macos searchDiscovery.lastExposure; defaults delete io.github.tingtmu.meowtab.macos searchDiscovery.hasSearched` in Terminal (a "does not exist" message is fine), and open MeowTab again. In Settings > Controls > Shortcuts when active…, check that "Show the search hint" is on. Open 8 or more windows, then open the switcher and hold it for 2 seconds without moving the selection. The hint, "Press S to search your windows.", appears below the pane, not over the cat. On a pane wide enough that the hint can't touch the cat, it may stay above. |
| 25 | peek-settings | First use | | Start without MeowTab data: on a first install, or with MeowTab quit, run `rm -rf ~/Library/Application\ Support/MeowTab` and `for k in someFrom manyFrom minShare maxShare picture.few picture.some picture.many; do defaults delete io.github.tingtmu.meowtab.macos meowtab.$k 2>/dev/null; done`, then open MeowTab. Open Settings from the menubar. MeowTab is first in the sidebar, with a star icon, and is the section shown. The cards show the three shipped cats, titled "Few · 1–2 windows", "Some · 3–7 windows" and "Many · 8+ windows", with no "Use default" button. "Some from" is 3, "Many from" 8, "With 1 window" 80% and "With many windows" 95%. The line under Restore defaults is empty. |
| 26 | peek-settings | Pushing a threshold past the other | | In Settings > MeowTab, lower "Many from" to 4; "Some from" stays 3. Raise "Some from" to 4: "Many from" becomes 5, and the cards read "Few · 1–3 windows", "Some · 4 windows" and "Many · 5+ windows". Lower "Many from" to 4: "Some from" becomes 3. Drag "With 1 window" to the right end: it stops at 99% and pushes "With many windows" to 100%. Drag "With many windows" to the left end: it stops at 31% and pushes "With 1 window" to 30%. Without relaunching, open the switcher with 3 windows open, then with 4: it shows the some cat, then the many cat. |
| 27 | peek-settings | Hand-edited invalid values | | Quit MeowTab, run `defaults write io.github.tingtmu.meowtab.macos meowtab.someFrom -int 9; defaults write io.github.tingtmu.meowtab.macos meowtab.manyFrom -int 5`, then open MeowTab. Open the switcher with 3 windows (the some cat) and with 8 (the many cat). In Settings > MeowTab, "Some from" is 3 and "Many from" 8, and the line under Restore defaults reads, in grey, "Some saved MeowTab settings were invalid, so their defaults are used." Move any control: the message goes away. Then quit MeowTab, run `defaults write io.github.tingtmu.meowtab.macos meowtab.picture.few -string ../x.png`, and open it again: the same message shows, and the few card shows the shipped cat with a "Use default" button. Click it: the button and the message go away. |
| 28 | peek-settings | Restore defaults | | In Settings > MeowTab, choose a custom picture for at least one card and change both thresholds and both heights. In Terminal, run `touch ~/Library/Application\ Support/MeowTab/images/keep-me.png`. Click Restore defaults. At once, every card shows its shipped cat with no "Use default" button, "Some from" is 3, "Many from" 8, the heights are 80% and 95%, and the line under the button is empty. `ls ~/Library/Application\ Support/MeowTab/images` lists only `keep-me.png`, and `defaults read io.github.tingtmu.meowtab.macos \| grep '"meowtab\.'` prints nothing. Open the switcher with 1, 3 and 8 windows: it shows the few, some and many shipped cats. Delete `keep-me.png` afterwards. |
| 29 | peek-settings | A custom "many" picture | | Copy a still PNG with a transparent background to the Desktop: `cp /Applications/MeowTab.app/Contents/Resources/chill_few.png ~/Desktop/cat.png` (the few cat, so it's easy to tell apart from the many cat). Drag `cat.png` from Finder onto the "Many · 8+ windows" card in Settings > MeowTab. At once, that card shows the few cat, a "Use default" button appears under it, and the line under Restore defaults is empty. The few and some cards are unchanged. Open the switcher with 8 or more windows: the peek is the few cat, with what's behind showing through its transparent parts and no box around it. With 1–2 and with 3–7 windows, the shipped few and some cats show. |
| 30 | peek-settings | Back to the shipped cat | | After "A custom "many" picture", run `ls ~/Library/Application\ Support/MeowTab/images` in Terminal: it lists one `many-<id>.png`. Click "Use default" on the many card. At once, the card shows the shipped many cat and the button disappears. `ls` again lists no `many-` file, and `defaults read io.github.tingtmu.meowtab.macos meowtab.picture.many` says the key does not exist. With 8 or more windows, the switcher shows the shipped many cat. |
| 31 | peek-settings | Renamed JPEG | | Make a JPEG named like a PNG: `sips -s format jpeg ~/Desktop/cat.png --out ~/Desktop/jpeg.png`; `file ~/Desktop/jpeg.png` says "JPEG image data". Drag it onto any card. The line under Restore defaults says, in red, "Choose a PNG picture. GIFs and other formats aren't supported yet.", and the card keeps its picture and buttons as they were. |
| 32 | peek-settings | GIF or animated PNG | | Make a GIF: `sips -s format gif ~/Desktop/cat.png --out ~/Desktop/cat.gif`. Choose… doesn't offer it, so drag it onto a card: the line says, in red, "Choose a PNG picture. GIFs and other formats aren't supported yet." Download the original file from https://commons.wikimedia.org/wiki/File:Animated_PNG_example_bouncing_beach_ball.png (an animated PNG) and pick it with Choose… on a card: the line says, in red, "Animated PNGs aren't supported yet. Choose a still PNG." Each time, the card keeps its picture. |
| 33 | peek-settings | Too large | | Make a PNG 9000 pixels wide: `sips -z 100 9000 ~/Desktop/cat.png --out ~/Desktop/wide.png`, and drop it on a card: the line says, in red, "That picture is too large (at most 8192 px a side and 32 megapixels)." Make a 12 MB file named like a PNG: `mkfile -n 12m ~/Desktop/big.png`. The file size is checked before anything else, so it stands in for a 12 MB PNG. Drop it: the line says, in red, "That file is over 10 MB." Each time, the card keeps its picture. |
| 34 | peek-settings | Large but valid | | Make a transparent 2000×1000 PNG: `sips -z 1000 2000 ~/Desktop/cat.png --out ~/Desktop/large.png`. On the few card, click Choose…: only PNG files can be picked. Pick `large.png`. The card shows the stretched cat, and the line under Restore defaults is empty. `sips -g pixelWidth -g pixelHeight -g hasAlpha ~/Library/Application\ Support/MeowTab/images/few-*.png` prints 1024, 512 and yes. With 1–2 windows, the switcher's peek is the wide cat, transparent around it. |
| 35 | peek-settings | Original moved | | Copy the picture: `cp ~/Desktop/cat.png ~/Desktop/moved.png`. On the some card, click Choose… and pick `moved.png`, then move `moved.png` to the Trash and empty it. The some card still shows the picture, and so does the switcher with 3–7 windows. Quit MeowTab and open it again: the card and the switcher still show it. |
| 36 | peek-settings | Saving fails | | After "Original moved", the some card has a custom picture, so MeowTab's folder exists. Run `cp /Applications/MeowTab.app/Contents/Resources/chill_many.png ~/Desktop/many.png` and `chmod 500 ~/Library/Application\ Support/MeowTab/images`. Drag `many.png` onto the some card. The line says, in red, "The picture couldn't be saved.", the card keeps the few cat it had, and the switcher with 3–7 windows still shows the few cat. Run `chmod 700 ~/Library/Application\ Support/MeowTab/images` afterwards. |
| 37 | peek-settings | Replacing the app | | With custom pictures on the few and some cards, set "Some from" to 4 and "With 1 window" to 70%. Quit MeowTab and replace /Applications/MeowTab.app with a fresh copy unzipped from the candidate's zip, then open it. If macOS asks for permissions again, grant them. Settings > MeowTab shows the same pictures, "Some from" 4 and 70%, and the switcher shows the custom pictures. |
| 38 | mood-peek | Damaged saved picture | | Give the some card a custom picture, then quit MeowTab. Damage MeowTab's copy: `printf broken > "$(ls ~/Library/Application\ Support/MeowTab/images/some-*.png)"`. Open MeowTab. With 3–7 windows, the switcher shows the shipped some cat, and switching works as usual. In Settings > MeowTab, the line under Restore defaults says, in grey, "Your picture for “some” couldn't be loaded, so the default cat is shown.", and the some card shows the shipped cat with a "Use default" button. Click "Use default": the button and the message go away, and `ls ~/Library/Application\ Support/MeowTab/images` lists no `some-` file. |
| 39 | peek-settings | VoiceOver in the MeowTab section | | Turn on VoiceOver (⌘F5) and move through Settings > MeowTab with Control-Option and the arrows. Each card's picture is read as "Picture for “few”" (or some, or many), and its buttons as "Choose a picture for “few”" and "Use the default picture for “few”". The steppers are read as "Some from" and "Many from", and the sliders as "With 1 window" and "With many windows", each with its value. Turn VoiceOver off afterwards (⌘F5). |

### 4. Updating

| # | Spec | Scenario | Result | Notes |
|---|------|----------|--------|-------|
| 40 | mac-release | Updating keeps permissions | | On `rc.1`, mark this row "Not tested — first candidate". From `rc.2` on, do this row before row 1, while the previous candidate is still installed with Accessibility and Screen Recording granted. Update as INSTALL.md step 7 says: quit MeowTab, replace /Applications/MeowTab.app with this candidate, and open it. macOS may first block the new copy, as it does any new download: open it as INSTALL.md step 3 says, which is not a Fail. MeowTab starts without asking for any permission: no permissions window appears, the switcher shows pictures of the windows, and releasing ⌥ switches to the selected window. If the permissions window appears instead, that's a Fail: say what it asked for, then grant again as step 7 says. Afterwards, so that rows 1 to 3 start from a first install, remove MeowTab: follow INSTALL.md step 8, including its data, and remove MeowTab from the Accessibility and Screen Recording lists in System Settings > Privacy & Security (select it and click −). |

### 5. Repository front page

| # | Spec | Scenario | Result | Notes |
|---|------|----------|--------|-------|
| 41 | fork-identity, mac-ci | Reading the repository; Notices at the root; Reading the README's compatibility section | | Open github.com/tingtmu/mac_meowtab in a browser. The file list includes NOTICE.md and LICENCE.md. Below it, before any instructions, the README credits AltTab and Louis Pontoise, with links that open github.com/lwouis/alt-tab-macos and github.com/sponsors/lwouis. Its Compatibility section says macOS 12.0 and later is targeted, names macOS 12, 13 and 14 as not tested, and lists the versions CI tested. |

### 6. Terminal install and uninstall

Do these two rows last, after rows 1–41, so that rows 1–3 still test the browser download. Rows 1–41 leave MeowTab installed, opened and granted, which is row 42's starting state. The removal command asks for your account password (`sudo`) only if macOS refuses to reset a permission entry; if it asks, say so in Notes.

| # | Spec | Scenario | Result | Notes |
|---|------|----------|--------|-------|
| 42 | mac-install-scripts | Full removal | | With MeowTab installed, opened and granted both permissions, run `curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/uninstall.sh \| bash` in Terminal. It prints one line per step, and no error. Then check that nothing is left. `ls /Applications/MeowTab.app`, `ls ~/Library/LaunchAgents/io.github.tingtmu.meowtab.macos.plist` and `ls ~/Library/Application\ Support/MeowTab` each say "No such file or directory". `defaults read io.github.tingtmu.meowtab.macos` fails ("does not exist"). In System Settings > Privacy & Security, MeowTab is in neither the Accessibility list (Device Control and Data Access on macOS 27) nor the Screen & System Audio Recording list (close and reopen the pane if it was open). If any of these fails, say which in Notes. |
| 43 | mac-install-scripts | Fresh install of a candidate; Update; No published release yet | | Start from row 42's result, with no MeowTab installed. First run `curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh \| bash` with no tag. While only pre-releases are published, it ends with an error that says to pass a tag, and `/Applications/MeowTab.app` does not exist. (If a release that isn't a pre-release exists by then, it installs that one: say so in Notes.) Then run `curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh \| bash -s -- v0.1.0-rc.1`, with the candidate's tag in place of `v0.1.0-rc.1` if it differs. Its last line says "MeowTab <tag> is installed". MeowTab opens with no "Open Anyway" step and no macOS warning, and shows its permissions window: both permissions are asked for again. Grant them as INSTALL.md step 4 says. Last, run the same command with the tag once more, as an update: MeowTab quits and opens again, no permissions window appears, and the switcher shows pictures of the windows. |

## Timing

Paste the output of `log stream --level debug --predicate 'category == "peek"'` from row 22, "Measuring on a real Mac" (20 openings with about 10 windows), and give the median and the maximum of its `update` times.

- Median: ms
- Maximum: ms

```text
Paste the log here.
```

## Feedback (optional)

This is a question, not a check: it has no Pass or Fail.

**Compared with AltTab, do the window tiles feel too small?**

MeowTab keeps room above the pane for the cat, so on a 1440×900 laptop its tiles are about 13 % smaller than AltTab's. That is kept for now and will be looked at again after this run. If you have used AltTab, say how the tiles compare.

Answer:

## Recording

The owner copies the whole filled-in sheet to `docs/acceptance/<tag>.md`, for example `docs/acceptance/v0.1.0-rc.1.md`. The tested macOS version and chip are evidence; they don't narrow the macOS 12.0+ target.

## Cross-check

For the owner; the tester can skip this. The table lists every scenario of the project's specs, plus `mac-release` and `mac-install-scripts`, which join them when the `mac-preview-release` and `mac-easy-install` changes are archived; the specs and changes are kept in a separate planning repository that isn't published. Each is checked by a unit test, a CI job, a row of this sheet, or more than one of these. A `release step: tasks.md <n.n>` entry is a check the owner makes in that task of the `mac-preview-release` change, outside CI and this sheet. A `reading check` entry is made by reading the named document against the scenario.

| Spec | Scenario | Checked by |
|------|----------|------------|
| fork-identity | Inspecting a CI build | CI: ci.yml `build` |
| fork-identity | About window | row 6 |
| fork-identity | Both apps installed | row 11 |
| fork-identity | Reading the repository | row 41 |
| fork-identity | Supporting the author from the app | row 7 |
| fork-identity | Notices at the root | row 41 |
| fork-identity | Licence unchanged | CI: ci.yml `build` |
| mac-ci | A pull request from a fork | CI: ci.yml `build` |
| mac-ci | A test fails on Intel only | CI: ci.yml `test` |
| mac-ci | Startup crash | CI: ci.yml `launch` |
| mac-ci | Reading the README's compatibility section | row 41 |
| offline-app | Launch on a runner | CI: ci.yml `launch` |
| offline-app | Static guard | CI: ci.yml `build` |
| offline-app | Inspecting the plist | CI: ci.yml `build` |
| offline-app | Weeks after installing | row 8 |
| offline-app | Settings window | row 9 |
| mood-peek | Scrolled grid with placeholders | row 13 |
| mood-peek | Typing a search | row 14 |
| mood-peek | Only placeholders | unit test: MoodPeekTests.testDefaultThresholdsPickTheMood (no mood at 0 windows); row 15 |
| mood-peek | Default boundaries | unit test: MoodPeekTests.testDefaultThresholdsPickTheMood; row 12 |
| mood-peek | Custom thresholds | unit test: MoodPeekTests.testCustomThresholdsPickTheMood; row 26 |
| mood-peek | Default range | unit test: MoodPeekTests.testShareRisesFromMinShareToMaxShare |
| mood-peek | Padded picture | unit test: MoodPeekTests.testUpIsTheArtRowsAboveThePaneInPoints; unit test: PeekPictureTests.testPaddedPictureIsAcceptedWithItsArtSpan |
| mood-peek | Two displays with different scales | row 20 |
| mood-peek | Rounded corners and a narrow pane | unit test: MoodPeekTests.testARounderCornerMovesThePeekIn; unit test: MoodPeekTests.testANarrowPaneScalesThePeekDownToFitBetweenTheMargins; row 12 |
| mood-peek | Thirty windows on a laptop display | unit test: MoodPeekTests.testThirtyWindowsOnALaptopDisplayKeepThePeekBelowTheTopMargin; row 13 |
| mood-peek | Very short usable area | unit test: MoodPeekTests.testTheBoxShrinksOnlyAsFarAsNeeded; unit test: MoodPeekTests.testAVeryShortUsableAreaStillFitsTheScaledPicture |
| mood-peek | A window closes while the switcher is open | unit test: MoodPeekTests.testTheReserveFollowsMaxShareAndUpFollowsTheCount (the room doesn't follow the count); row 16 |
| mood-peek | Cancel and reopen quickly | row 17 |
| mood-peek | Clicking where the picture is | row 18 |
| mood-peek | VoiceOver | row 19 |
| mood-peek | Measuring on a real Mac | row 22 |
| mood-peek | Damaged saved picture | row 38 |
| peek-settings | First use | unit test: MeowTabStoreTests.testEmptyStorageGivesTheDefaults; row 25 |
| peek-settings | Pushing a threshold past the other | unit test: MoodPeekTests.testRaisingSomeFromToManyFromPushesManyFromUp; row 26 |
| peek-settings | Hand-edited invalid values | unit test: MeowTabStoreTests.testReversedThresholdsFallBackAndTheSharesAreKept; row 27 |
| peek-settings | A custom "many" picture | row 29 |
| peek-settings | Back to the shipped cat | unit test: MeowTabStoreTests.testUseDefaultRemovesOnlyThatMoodsPicture; row 30 |
| peek-settings | Renamed JPEG | unit test: PeekPictureTests.testJPEGNamedPNGIsNotAcceptedAsPNG; row 31 |
| peek-settings | GIF or animated PNG | unit test: PeekPictureTests.testGIFIsNotAcceptedAsPNG; unit test: PeekPictureTests.testTwoFrameAPNGIsAnimated; row 32 |
| peek-settings | Too large | unit test: PeekPictureTests.testFileOverTenMegabytesIsTooBig; unit test: PeekPictureTests.testPictureOver8192PixelsWideIsTooLarge; row 33 |
| peek-settings | Large but valid | unit test: PeekPictureTests.testLargePictureIsScaledDownKeepingItsTransparency; row 34 |
| peek-settings | Original moved | unit test: MeowTabStoreTests.testTheStoredCopyOutlivesTheImportedFile; row 35 |
| peek-settings | Saving fails | unit test: MeowTabStoreTests.testAFailedSaveKeepsThePreviousPicture; row 36 |
| peek-settings | Replacing the app | row 37 |
| peek-settings | Restore defaults | unit test: MeowTabStoreTests.testRestoreDefaultsRemovesOnlyMeowTabsData; row 28 |
| peek-settings | Running the tests on a configured machine | unit test: MeowTabStoreTests.tearDownWithError, after every MeowTabStoreTests test (run only on CI runners, which have no MeowTab data) |
| mac-release | Requirement drift | CI: release.yml `package` |
| mac-release | Updating keeps permissions | row 40 |
| mac-release | Version mismatch | CI: release.yml `version`; release step: tasks.md 2.2 |
| mac-release | A candidate | CI: release.yml `package`; release step: tasks.md 4.1 |
| mac-release | First open on macOS 26 | row 1 |
| mac-release | One display only | row 20; release step: tasks.md 5.1 |
| mac-release | Run on a GitHub-hosted runner | rows 1–3 and 40, with their "VM, SIP off" note; release step: tasks.md 4.2 |
| mac-release | Dry run | release step: tasks.md 2.3 |
| mac-release | Promoting rc.2 | release step: tasks.md 5.1 |
| mac-release | Tester's screenshot | release step: tasks.md 5.1 |
| mac-install-scripts | Fresh install of a candidate | CI: install-scripts.yml `check`, step "Fresh install"; row 43 |
| mac-install-scripts | Update | CI: install-scripts.yml `check`, step "Update"; row 43 |
| mac-install-scripts | No published release yet | row 43 |
| mac-install-scripts | Tampered download | CI: install-scripts.yml `check`, step "Tampered download" |
| mac-install-scripts | Wrong signer | CI: install-scripts.yml `check`, step "Wrong signer" |
| mac-install-scripts | Reading the guide | reading check: docs/install.md, section "Quick install from Terminal" |
| mac-install-scripts | Full removal | CI: install-scripts.yml `check`, step "Full removal"; row 42 |
| mac-install-scripts | Nothing installed | CI: install-scripts.yml `check`, step "Nothing installed" |
| mac-install-scripts | A script change | CI: install-scripts.yml `check` and `lint` |

Rows 2–5, 10, 21, 23, 24 and 39 have no scenario of their own: they check INSTALL.md's permission steps, upstream switching, traffic after permissions, fullscreen Spaces, two more peek cases (another shortcut and the search hint) and VoiceOver in the MeowTab section.
