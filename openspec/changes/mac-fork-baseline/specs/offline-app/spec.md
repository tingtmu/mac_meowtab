# Spec Delta

## Purpose

MeowTab makes no network traffic of its own, never updates itself (into upstream AltTab or anything else), and offers all of AltTab's features without a trial or licence.

## ADDED Requirements

### Requirement: No app-initiated network traffic
MeowTab SHALL NOT create Sparkle's updater, start AppCenter crash reporting, contact AltTab's licence server, or send the feedback form. Its menubar SHALL have no "Check for updates…", "Send feedback…", "Get Pro", "My Account" or "Support this project" items. Its settings SHALL have no updates rows. Links the user clicks MAY open in the browser.

#### Scenario: Launch on a runner
- **WHEN** CI launches the built app on an Apple silicon runner and an Intel runner and waits 20 s
- **THEN** the process is running, it holds no internet sockets, and no crash report was written

#### Scenario: Static guard
- **WHEN** a commit reintroduces `SPUStandardUpdaterController(`, `AppCenterCrash()`, the licence URL handler, a `shared` licence manager that revalidates, or the feedback or update menu items
- **THEN** `scripts/meowtab/check_offline.sh` fails the CI build

### Requirement: No automatic update
The built `Info.plist` SHALL have no `SUPublicEDKey`, and SHALL set `SUEnableAutomaticChecks` to false and `NSPrincipalClass` to `NSApplication`.

#### Scenario: Inspecting the plist
- **WHEN** CI reads the built `Info.plist` with `PlistBuddy`
- **THEN** `SUPublicEDKey` is absent, `SUEnableAutomaticChecks` is false, and `NSPrincipalClass` is `NSApplication`

### Requirement: AltTab's Pro features without a licence
The licence state SHALL be Pro from launch, permanently. MeowTab SHALL show no trial countdown, upgrade window, upgrade popover, Pro checkout or account page. Every AltTab feature SHALL work: app-icon and title styles, auto size, extra shortcuts and search.

#### Scenario: Weeks after installing
- **WHEN** MeowTab has been installed for more than 14 days
- **THEN** no trial or upgrade prompt has appeared, and a second shortcut and in-switcher search work

#### Scenario: Settings window
- **WHEN** the user goes through every section of Settings
- **THEN** there is no Upgrade entry, and no control leads to an upgrade or account view
