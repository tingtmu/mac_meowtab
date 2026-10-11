# Spec Delta

## Purpose

What makes MeowTab for Mac its own app: its name, bundle ID and version, its separation from an installed AltTab, and the credit and licence notices it owes AltTab.

## ADDED Requirements

### Requirement: Own name, bundle ID and version
The app SHALL be built as `MeowTab.app` with `CFBundleName` `MeowTab` and bundle ID `io.github.tingtmu.meowtab.macos`. Its version SHALL come from the repository's `MEOWTAB_VERSION` file. It SHALL keep upstream's deployment target of macOS 12.0.

#### Scenario: Inspecting a CI build
- **WHEN** CI reads the built app's `Info.plist`
- **THEN** `CFBundleIdentifier` is `io.github.tingtmu.meowtab.macos`, `CFBundleName` is `MeowTab`, `CFBundleShortVersionString` equals `MEOWTAB_VERSION`, and `LSMinimumSystemVersion` is `12.0`

#### Scenario: About window
- **WHEN** the user opens About from the menubar
- **THEN** it shows MeowTab and its version, a "Source code" link to github.com/tingtmu/mac_meowtab, and a "Based on AltTab" link to github.com/lwouis/alt-tab-macos

### Requirement: Runs beside AltTab without sharing data
MeowTab SHALL keep separate copies of everything keyed on the bundle ID: its preferences, its login-item plist in `~/Library/LaunchAgents/`, its Keychain entries, its URL scheme and its macOS permission entries. It SHALL never read or write AltTab's.

#### Scenario: Both apps installed
- **WHEN** AltTab and MeowTab are both installed and the user changes a setting in MeowTab
- **THEN** AltTab's settings are unchanged, and each app has its own entry under Privacy & Security > Accessibility

### Requirement: Credit to AltTab and its author
The README's first section SHALL say that MeowTab for Mac is a modified version of AltTab by Louis Pontoise and contributors, thank the author, and link the upstream repository (github.com/lwouis/alt-tab-macos) and the author's sponsor page (github.com/sponsors/lwouis). The About window SHALL offer the same sponsor link.

#### Scenario: Reading the repository
- **WHEN** someone opens the repository's front page
- **THEN** the README credits AltTab and its author with both links before any MeowTab instructions

#### Scenario: Supporting the author from the app
- **WHEN** the user clicks "Sponsor AltTab's author" in the About window
- **THEN** the browser opens github.com/sponsors/lwouis

### Requirement: GPL-3.0 notices
`NOTICE.md` SHALL name the upstream project and its base commit, and state that the work was modified, by whom, from when, and how. `LICENCE.md` SHALL be identical to upstream's. `docs/acknowledgments.md` SHALL keep upstream's third-party notices.

#### Scenario: Notices at the root
- **WHEN** someone lists the repository's root
- **THEN** `NOTICE.md` and `LICENCE.md` are there

#### Scenario: Licence unchanged
- **WHEN** CI compares `LICENCE.md` with commit `6d8940b5307d7348aaca70259c28147fc5ab00b3`
- **THEN** there is no difference
