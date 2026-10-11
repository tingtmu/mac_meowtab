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
