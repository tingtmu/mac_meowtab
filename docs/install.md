# Install MeowTab for Mac

MeowTab for Mac is self-signed and not notarized by Apple, so macOS asks once the first time you open it. The steps below take a few minutes. MeowTab is built for macOS 12 or later, on Apple silicon or Intel.

Some of MeowTab's on-screen text still says "AltTab", because MeowTab is built from AltTab (see Known issues at <https://github.com/tingtmu/mac_meowtab#known-issues>). Where it does, it means MeowTab.

To install, update or remove MeowTab with one Terminal command instead, see [Quick install from Terminal](#quick-install-from-terminal), the last section.

## 1. Download

Download `MeowTab-<version>-mac.zip` from <https://github.com/tingtmu/mac_meowtab/releases>. `<version>` is the release's version, such as `v0.1.0-rc.1`.

To check the download, which is optional, run this in Terminal (Applications > Utilities). Use the zip's real name, or drag the zip into the Terminal window after `shasum -a 256 `.

```bash
shasum -a 256 ~/Downloads/MeowTab-<version>-mac.zip
```

The result must match the one in `SHA256SUMS.txt` on the release page, or in the release notes.

## 2. Unzip it and move the app

Double-click the zip to unzip it (Safari may have done this for you). Before you open anything, drag `MeowTab.app` from the unzipped folder into your Applications folder.

## 3. Open it the first time

macOS stops the first open of an app that Apple has not notarized. What to do depends on your macOS version: Apple menu > About This Mac shows it.

**macOS 15 and later (15 Sequoia, 26 Tahoe):**

- Open MeowTab from Applications. macOS shows a warning that it was not opened. Click "Done", not "Move to Trash".
- Choose Apple menu > System Settings, click "Privacy & Security" in the sidebar, and scroll down to "Security".
- Click "Open Anyway". This button is available for about an hour after you try to open the app. If it has gone, open MeowTab again.
- If macOS shows the warning again, confirm that you want to open the app. Enter your password, or use Touch ID, when macOS asks for it.

No Terminal command is needed. If you moved MeowTab to the Trash by mistake, unzip the download again and start from step 2.

**macOS 14 and earlier:** in the Finder, not Launchpad, Control-click MeowTab in Applications, choose "Open", then click "Open".

You never need to turn off any macOS security setting for this. After this first open, MeowTab opens normally.

## 4. Grant permissions

MeowTab opens a window called "AltTab requires some permissions". It takes you through two permissions, one at a time. MeowTab needs its own, even if AltTab already has them.

- **Accessibility (required).** Click "Grant permission", then "Open System Settings" in the macOS prompt ("Open System Preferences" before macOS 13). MeowTab is in the list: switch it on. macOS may ask for your password or Touch ID. On macOS 27, MeowTab's window calls this permission "Device Control", and System Settings lists it as "Device Control and Data Access".
- **Screen Recording (optional).** Do the same. System Settings calls this list "Screen & System Audio Recording" on macOS 15 and later. Or click "Continue without thumbnails": the switcher then shows app icons instead of window previews. To change your mind later, choose "Check permissions…" from MeowTab's menu bar icon.

When both are done, the window closes by itself. MeowTab has no Dock icon: look for its icon in the menu bar. Hold ⌥ (Option) and press ⇥ (Tab) to open the switcher. If you use AltTab, do step 5 first.

## 5. If AltTab is installed

By default, both apps open the switcher with ⌥⇥ (Shortcut 1) and with ⌥ and the key above Tab (Shortcut 2). Quit AltTab (it comes back at login if its "Start at login" is on), or give one of the two apps other shortcuts.

To change MeowTab's, click its menu bar icon, choose "Settings…", then "Controls" in the sidebar. Select "Shortcut 1". Next to "Trigger", click the keys after "Hold" or "and press", then press the keys you want instead. Do the same for "Shortcut 2".

## 6. Start at login

MeowTab starts at login by default. To turn this off, click its menu bar icon, choose "Settings…", then "General", and switch off "Start at login".

## 7. Updating

Quit MeowTab (menu bar icon > "Quit MeowTab"), then drag the new `MeowTab.app` into Applications and choose "Replace". Your pictures and settings carry over, and so should your permissions. The new copy is a new download, so macOS may ask again the first time you open it (step 3). To update from Terminal instead, run the install command again, as [Quick install from Terminal](#quick-install-from-terminal) says.

If macOS asks for the permissions again, which happens only after the signing certificate has changed, remove MeowTab from the permission lists. In System Settings > Privacy & Security, open "Accessibility" and "Screen & System Audio Recording", select MeowTab in each, and click the minus button. Then open MeowTab and grant the permissions again, as in step 4.

## 8. Removing MeowTab

To remove MeowTab and all its data with one Terminal command, see [Quick install from Terminal](#quick-install-from-terminal). To keep your pictures and settings, follow the steps here.

- Open "Settings…" from the menu bar icon, choose "General", and switch off "Start at login". That removes MeowTab's login item from `~/Library/LaunchAgents`. Do this before you delete the app.
- Quit MeowTab with "Quit MeowTab", at the bottom of the Settings sidebar or in the menu bar icon's menu. Then drag `MeowTab.app` from Applications to the Trash.

To delete MeowTab's data as well, which is optional, run these in Terminal. The first deletes MeowTab's copies of your pictures and leaves your original files alone. The second deletes MeowTab's settings.

```bash
rm -r ~/Library/Application\ Support/MeowTab
defaults delete io.github.tingtmu.meowtab.macos
```

The app also writes two small preference domains that hold no settings. The first keeps flags for AltTab's Pro prompts, and the second keeps the usage counts that the About window shows. To delete them too, which is also optional:

```bash
defaults delete io.github.tingtmu.meowtab.macos.license
defaults delete io.github.tingtmu.meowtab.macos.usage
```

A "does not exist" message from `defaults` is harmless.

## Quick install from Terminal

This is a shortcut for steps 1 to 3. Steps 1 to 8 above stay the main way to install.

To install the newest release that isn't a pre-release, and open it:

```bash
curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh | bash
```

A test candidate, a pre-release such as `v0.1.0-rc.1`, is not picked this way: without a tag the command stops and says to pass one. Give the release's tag after `bash -s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh | bash -s -- v0.1.0-rc.1
```

Run the same command again to update. It quits MeowTab, replaces the app and opens the new one. Your pictures and settings carry over, and so should your permissions.

To remove MeowTab, run:

```bash
curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/uninstall.sh | bash
```

This removes everything: the app, its login item, your pictures and settings, and MeowTab's entries in the Accessibility and Screen Recording lists. To keep your pictures and settings, follow step 8 instead. If macOS refuses to reset an entry, the command asks for your account password (`sudo`) and tries again.

**Read the script first.** To read the install script before it runs, pipe it to `less` (press Q to leave):

```bash
curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh | less
```

Or open it in a browser: <https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh>. The removal script is at <https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/uninstall.sh>.

**What this skips.** The one-liner opens MeowTab without "Open Anyway" (step 3). Files that `curl` downloads in Terminal aren't marked as downloaded from the internet, so macOS's first-open check doesn't run. Instead, before it replaces anything, the script checks that the download's SHA-256 matches the release's `SHA256SUMS.txt`, that the app's signature is valid, and that it is signed by the project's certificate (its designated requirement). If a check fails, it stops and leaves an installed MeowTab as it was. It never turns Gatekeeper or SIP off.

**Permissions.** The script doesn't grant any. After a first install, MeowTab opens with its permissions window: grant them by hand, as in step 4. An update keeps them.
