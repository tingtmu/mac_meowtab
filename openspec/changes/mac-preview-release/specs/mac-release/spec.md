# Spec Delta

## Purpose

How MeowTab for Mac reaches people: a stable signature, tagged packages with hashes and source, an install guide, a recorded real-Mac acceptance run, and a preview that ships exactly what was accepted.

## ADDED Requirements

### Requirement: One stable signing identity
Release builds SHALL be signed with the project's own self-signed certificate, which is stored only in the repository secrets `MEOWTAB_CERT_P12` and `MEOWTAB_CERT_PASSWORD`. Their designated requirement SHALL equal `docs/designated-requirement.txt`. Releases SHALL never be signed ad hoc or with upstream's identity, and SHALL never claim Developer ID signing or notarization.

#### Scenario: Requirement drift
- **WHEN** a release build's `codesign -d -r-` output differs from `docs/designated-requirement.txt`
- **THEN** the release workflow fails, and no release is created

#### Scenario: Updating keeps permissions
- **WHEN** the tester replaces `rc.N` with `rc.N+1` after granting Accessibility and Screen Recording to `rc.N`
- **THEN** `rc.N+1` works without granting them again

### Requirement: Tagged packages
A tag `vX.Y.Z` or `vX.Y.Z-rc.N` SHALL start the release workflow. The workflow SHALL fail before building when `X.Y.Z` differs from `MEOWTAB_VERSION`, and SHALL run the full CI workflow before packaging. It SHALL attach `MeowTab-<tag>-mac.zip`, holding the app, `LICENCE.md`, `NOTICE.md` and `INSTALL.md`, plus `SHA256SUMS.txt`, to a draft GitHub release.

#### Scenario: Version mismatch
- **WHEN** `v0.2.0-rc.1` is pushed while `MEOWTAB_VERSION` is `0.1.0`
- **THEN** the workflow fails at the version check, and no release is created

### Requirement: Release notes
Every release's notes SHALL give:
- the label: test candidate or preview;
- the zip's SHA-256;
- a link to the exact source tag;
- the signing status;
- the target versus the tested macOS versions;
- the credit to AltTab, with its repository and sponsor links.

#### Scenario: A candidate
- **WHEN** `v0.1.0-rc.1` is pushed and CI passes
- **THEN** a draft pre-release "MeowTab for Mac v0.1.0-rc.1" holds the zip and `SHA256SUMS.txt`, its notes are labelled "Test candidate — not yet checked on a real Mac", and the zip's hash matches both

### Requirement: Install guide
`docs/install.md`, shipped in the zip as `INSTALL.md` and linked from the README, SHALL explain:
- first open on macOS 15 and later (Privacy & Security > Open Anyway) and on macOS 14 and earlier (Control-click > Open);
- granting Accessibility, and granting or skipping Screen Recording;
- running beside AltTab;
- turning off launch at login;
- updating and re-granting;
- removing the app and its data.

It SHALL NOT suggest disabling Gatekeeper or SIP.

#### Scenario: First open on macOS 26
- **WHEN** someone opens the downloaded app on macOS 26 for the first time and macOS blocks it
- **THEN** the guide's steps get it open through Privacy & Security, with no Terminal command

### Requirement: Recorded real-Mac acceptance
Each candidate given to the tester SHALL get a record, `docs/acceptance/<tag>.md`. The record SHALL give the date, macOS version, chip and displays, a result for every row of `docs/acceptance.md`, and the peek timing log. A row the tester couldn't run SHALL be "Not tested", with the reason, and SHALL never count as a pass. The tested configuration SHALL be reported as evidence, without changing the macOS 12.0+ target.

#### Scenario: One display only
- **WHEN** the tester has a single display
- **THEN** the two-display rows read "Not tested — one display", and the release notes list them as untested

### Requirement: The preview ships what was accepted
`v0.1.0` SHALL be published only from a candidate whose record has no Fail row. It SHALL use the same zip bytes, and therefore the same SHA-256, as that candidate. Its notes SHALL link the record. The README's quick start SHALL then point to the download and the install guide.

#### Scenario: Promoting rc.2
- **WHEN** `v0.1.0-rc.2`'s record has only Pass and "Not tested" rows
- **THEN** the `v0.1.0` release's zip has the same SHA-256 as `rc.2`'s, and its notes link `docs/acceptance/v0.1.0-rc.2.md`

### Requirement: Private captures
Screenshots and recordings in the README and release notes SHALL come from a CI runner or show only demo windows over a plain desktop picture, never a real user's windows, titles or files.

#### Scenario: Tester's screenshot
- **WHEN** the tester sends a screenshot of the peek for the README
- **THEN** it shows only empty TextEdit or Finder demo windows over a plain background, or it isn't used
