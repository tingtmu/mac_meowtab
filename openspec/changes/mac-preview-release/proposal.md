# Proposal

Third of three changes: `mac-fork-baseline` → `mac-png-peek` → **mac-preview-release**. Starts after `mac-png-peek` is archived.

## Why

After the first two changes, MeowTab for Mac builds and passes its tests on CI, but nobody has run it on a real Mac. Its CI builds are also not ready for people:

- **Ad-hoc signed**, so macOS forgets the Accessibility and Screen Recording grants on every new build.
- **Unlabelled.**
- **No install guide.** A non-notarized app needs one on macOS 15 and later.

This change turns a build into a downloadable test candidate, gets one complete real-Mac acceptance run, and only then publishes the 0.1.0 preview.

## What Changes

- **One stable signing identity.**
  - **Certificate.** A self-signed code-signing certificate is made once with upstream's own script (`scripts/codesign/generate_selfsigned_certificate.sh`) and kept as two repository secrets.
  - **Signing.** Release builds are signed with it, so their designated requirement stays the same from version to version. That is what lets macOS keep the permission grants through updates.
  - **CI check.** CI compares the requirement with a committed copy.
  - **Not covered.** This is not Developer ID signing or notarization: Gatekeeper still asks once, on first open.
- **A release workflow** for tags `v0.1.0-rc.N` and `v0.1.0`. It:
  - checks the tag against `MEOWTAB_VERSION`;
  - runs the full CI workflow (build, tests, launch);
  - signs the app and packages `MeowTab-<tag>-mac.zip` (the app, `LICENCE.md`, `NOTICE.md`, `INSTALL.md`) with `SHA256SUMS.txt`;
  - opens a draft GitHub release whose notes give the label, hashes, the exact source tag, signing status, compatibility evidence and the credit to AltTab.
- **An install guide** (`docs/install.md`, linked from the README):
  - first open on macOS 15 and 26 (Privacy & Security > Open Anyway) and on 14 and earlier (Control-click > Open);
  - granting permissions;
  - quitting AltTab or changing its shortcut;
  - launch at login, updating, and removing the app and its data.

  It never asks users to disable Gatekeeper or SIP.
- **One real-Mac acceptance run.**
  - **Candidates.** Each `rc` is published as a pre-release labelled "Test candidate".
  - **Run.** The tester works through `docs/acceptance.md` on their Mac.
  - **Record.** The result is recorded as `docs/acceptance/<tag>.md`, with the macOS version, chip, each check's result and the peek timing. Checks the tester's equipment can't cover are marked "Not tested", with the reason.
- **The preview.** `v0.1.0` is published only from an `rc` whose record has no failures. It ships the same zip bytes the tester accepted. The README's quick start then switches to "download".
- **Out of scope:** Developer ID signing and notarization (they need a paid Apple Developer account; a later option), a Homebrew cask (Homebrew is disabling casks that fail Gatekeeper), and automatic updates.

## Capabilities

### New Capabilities

- `mac-release`: signing identity, tagged packaging, install guide, acceptance record and the preview gate.

### Modified Capabilities

None. Moving the CI build steps into `scripts/meowtab/build.sh` and making `ci.yml` callable changes no `mac-ci` requirement.

## Impact

- **CI and release:**
  - new `.github/workflows/release.yml`, `scripts/meowtab/build.sh` and `scripts/meowtab/setup_release_signing.sh`;
  - `.github/workflows/ci.yml` gains `on: workflow_call` and calls `build.sh`;
  - `scripts/codesign/generate_selfsigned_certificate.sh` gains optional third and fourth arguments, the certificate's name and its validity in days (defaults unchanged).
- **Docs:**
  - new `docs/install.md`, `docs/release-notes-template.md`, `docs/designated-requirement.txt` and `docs/acceptance/<tag>.md`;
  - `docs/acceptance.md` finished as a run sheet;
  - `README.md` gains Install and Download sections;
  - ROADMAP updated.
- **Secrets:** `MEOWTAB_CERT_P12` and `MEOWTAB_CERT_PASSWORD`, set by the owner.
