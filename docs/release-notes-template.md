**{{LABEL}}**

- **Download:** `{{ZIP}}`. Its SHA-256, also in `SHA256SUMS.txt`, is `{{SHA256}}`.
- **Source:** [{{REF}}](https://github.com/tingtmu/mac_meowtab/tree/{{REF}}), the exact source of this build. It is the Corresponding Source under GPL-3.0 §6; GitHub also attaches source archives to the release.
- **Signing:** Self-signed, not notarized. macOS asks once on first open; see INSTALL.md.
- **Compatibility:**
  - Target: macOS 12.0 or later, on Apple silicon and Intel.
  - CI on this commit ([run]({{RUN_URL}})): unit tests on macOS 15 (Apple silicon), macOS 15 (Intel) and macOS 26 (Apple silicon); launch check on macOS 15 (Apple silicon) and macOS 15 (Intel).
  - Real Mac: not yet checked.
  - macOS 12–14: not tested.
- **Credit:** Based on [AltTab](https://github.com/lwouis/alt-tab-macos) by Louis Pontoise and contributors. If it's useful to you, please consider [sponsoring its author](https://github.com/sponsors/lwouis).
