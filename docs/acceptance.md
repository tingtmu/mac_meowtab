# Acceptance checklist

The manual checks for MeowTab for Mac that CI cannot do. A tester with a real Mac works through the table below on a build from CI.

For each row, do what the Notes column says, then fill in Result:

- **Pass**: the scenario's expected outcome happened.
- **Fail**: it did not. Say what happened instead in Notes.
- **Not tested**: you did not check it. Say why in Notes. "Not tested" never counts as a pass.

| Spec | Scenario | Result | Notes |
|------|----------|--------|-------|
| fork-identity | About window | | Open About from the menubar. It shows MeowTab and its version. "Source code" opens github.com/tingtmu/mac_meowtab and "Based on AltTab" opens github.com/lwouis/alt-tab-macos. |
| fork-identity | Supporting the author from the app | | In the About window, click "Sponsor AltTab's author". The browser opens github.com/sponsors/lwouis. |
| offline-app | Weeks after installing | | Use MeowTab for more than 14 days after installing it. To check sooner: quit MeowTab, run `defaults write io.github.tingtmu.meowtab.macos.license trialStartDate -float $(( $(date +%s) - 20 * 86400 ))` in Terminal, then open MeowTab again and use it for a while. No trial countdown, upgrade window or upgrade popover appears at any point. In Settings > Controls, add a second shortcut and open the switcher with it. Open the switcher and type: the search filters the windows. |
| offline-app | Settings window | | Open every section in the Settings sidebar (Appearance, Controls, General, Exceptions). The sidebar has no Upgrade entry, "Get Pro" or "Pro activated" button above Quit. Wherever a Pro badge appears, use the control next to it: in Appearance, pick the app-icon and title styles and Auto size; in Controls, add a second shortcut, set a shortcut's "After keys are released" to Search, and in "Shortcuts when active…" record the Search shortcut. Each choice applies, and nothing opens an upgrade or account view. |
| offline-app | No traffic after permissions | | CI only checks the phase before permissions. Grant Accessibility (and Screen Recording if you like), then use MeowTab for at least 2 minutes: open the switcher several times, open Settings and About. Meanwhile, in Terminal, run `lsof -nP -a -i -p $(pgrep -x MeowTab)` a few times, or `nettop -P -L 1 -p $(pgrep -x MeowTab)`. Neither shows a connection at any point. Clicking a link in About opens the browser; that traffic is the browser's, not MeowTab's. |
| fork-identity | Both apps installed | | Install AltTab next to MeowTab and run both. Change a setting in MeowTab, then open AltTab's Settings: the same setting is unchanged there. In System Settings > Privacy & Security > Accessibility, AltTab and MeowTab each have their own entry. |
