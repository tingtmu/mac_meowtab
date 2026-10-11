# Design

## Context

See [proposal.md](proposal.md). Upstream is AltTab v11.9.0, a lightweight tag on commit `6d8940b5307d7348aaca70259c28147fc5ab00b3` (2026-10-06). It is also the latest release as of 2026-10-11. Line numbers below are at that tag. The source was read on 2026-10-11.

| Area | At v11.9.0 |
| --- | --- |
| Project | `alt-tab-macos.xcodeproj`. Targets `alt-tab-macos` (the app) and `unit-tests`. Shared schemes `Debug`, `Release`, `Test`. |
| Dependencies | Vendored local Swift packages only: `vendor/Sparkle` (2.9.1, dynamic), `vendor/ShortcutRecorder` (static), `vendor/AppCenter` (4.3.0 plus PLCrashReporter, static). No CocoaPods. |
| Config | `config/base.xcconfig`: `PRODUCT_NAME = AltTab` (3), `PRODUCT_BUNDLE_IDENTIFIER = com.lwouis.alt-tab-macos` (4), `MACOSX_DEPLOYMENT_TARGET = 12.0` (9), `SWIFT_VERSION = 5.8` (10), warnings as errors (11). `config/release.xcconfig` signs as upstream's Developer ID (5). Both include `config/local.xcconfig` last, and `/config/local.xcconfig` is git-ignored. |
| Version | `Info.plist` (repo root) reads `$(CURRENT_PROJECT_VERSION)`, which no committed file sets; upstream CI writes it. |
| SDK | The code calls macOS 26 APIs (`HelperExtensions.swift:280-281`), so it needs an Xcode 26 SDK. Upstream CI uses Xcode 26.0.1 on `macos-15`. |
| Upstream CI | `.github/workflows/ci_cd.yml` runs on push to `master` only, in environment `production`. It uses 9 secrets and signs, notarizes, uploads symbols, updates the appcast and website, and publishes. |
| Tests | `unit-tests` compiles a hand-picked list of production files plus `src/_test-support/Mocks.swift`. It has no test host and needs no signing or permissions. About 68 `*Tests.swift` files. |
| Network | Four paths:<br>1. Sparkle (`App.swift:564-575`; feed from `SparkleDelegate.swift:26-28`).<br>2. AppCenter crash upload (`App.swift:604`, `AppCenterCrashes.swift`).<br>3. The licence server (`RemoteLicenseClient.swift:103-109`, revalidation at `LicenseManager.swift:244-249`, URL activation at `App.swift:677-702`).<br>4. The feedback form (`FeedbackWindow.swift:440-451`).<br>Links opened in the browser are user actions. |
| Pro | 14-day trial (`LicenseManager.swift:27`). Gated features (`ProFeature.swift:8-13`): app-icon and title styles, auto size, search-on-release, extra shortcuts and in-switcher search. In `.pro`, prompts are suppressed (`ProTransitionManager.swift:212`) and the scheduler is cancelled (`:177-181`). |

The developer has no Mac. GitHub-hosted runners (2026-10-11):

- **Available:** `macos-15` (arm64) and `macos-15-intel` (x64), both on macOS 15.7 with Xcode 26.0.1 installed (default 16.4). `macos-26` (arm64) has Xcode 26.0.1 to 26.6. `macos-26-intel` also exists.
- **Leaving:** `macos-14` is unsupported after 2026-11-02.
- **No runtime coverage:** no runner provides macOS 12 or 13.
- **Desktop:** runners have an auto-logged-in GUI session, so an app can be launched.

## Goals / Non-Goals

**Goals:** a renamed fork that coexists with AltTab, makes no network traffic of its own, keeps every upstream feature working, credits upstream as GPL-3.0 requires, and goes green on CI with no secrets.

**Non-Goals:** removing AltTab features or packages, the peek, user-facing signing or releases, and translating new strings.

## Decisions

### 1. A GitHub fork, with `main` at the pinned commit

1. The owner forked `lwouis/alt-tab-macos` as `tingtmu/mac_meowtab`, copying the master branch only. The "forked from" line on the repo page is a visible credit.
2. The checkout is this planning folder itself, whose `.git` had no commits. `openspec/` and `ROADMAP.md` are already in place, so there is one plan, no copy:

```text
git remote add origin https://github.com/tingtmu/mac_meowtab.git
git remote add upstream https://github.com/lwouis/alt-tab-macos.git
git fetch origin
git fetch upstream --tags
git checkout -b main 6d8940b5307d7348aaca70259c28147fc5ab00b3
```

3. Delete upstream's `CLAUDE.md` and `AGENTS.md`, and their two references in `project.pbxproj` (group entries only, in no build phase). Add `/CLAUDE.md` to `.gitignore`: the project's `CLAUDE.md` stays local. `.git/info/exclude` keeps out `peek-alttab/` (the Windows repo) and OpenSpec's generated `.agents/` and `.claude/skills/openspec-*/`.
4. In the same first commit, delete `ci_cd.yml` and add `ci.yml`. Push `main` and make it the default branch.
5. Enable Actions, which forks start with disabled.
6. Leave `master` untouched; upstream updates come in later by merging tags from `upstream`.

**Line endings and file modes (Windows authoring).** Edit with LF line endings. Scripts written on Windows have no executable bit, so the workflow calls them as `bash scripts/meowtab/<name>.sh`.

### 2. Identity

- **Product name and bundle ID:** `config/base.xcconfig:3` becomes `PRODUCT_NAME = MeowTab` and `:4` becomes `PRODUCT_BUNDLE_IDENTIFIER = io.github.tingtmu.meowtab.macos`.
- **Product file name:** update the `AltTab.app` product reference in `project.pbxproj` (854, 1519, 2011) and `BuildableName` in `Debug.xcscheme` and `Release.xcscheme` to `MeowTab.app`.
- **Version:** a new one-line `MEOWTAB_VERSION` file (`0.1.0`) is the only version source. CI copies it into `config/local.xcconfig` as `CURRENT_PROJECT_VERSION`.
- **What follows the bundle ID with no code:**
  - the preferences domain (`UserDefaults.standard`)
  - the login-item plist name (`LoginItem.swift:10-24`)
  - the licence Keychain service and defaults suite (`LicenseManager.swift:4-15`)
  - the URL scheme (`Info.plist:46-58`)
  - the macOS permission entries
- **Display name:** `App.name` comes from `CFBundleName`, so menus, the About window and permission screens say MeowTab.
- **Strings left alone:** about ten English strings hard-code "AltTab", for example the Screen Recording callout (`Menubar.swift:457`). Changing a string changes its localization key, which loses the 20 translations for it, so they stay as they are and the README lists them as a known issue.

### 3. Offline: cut each network path where it starts

Sparkle and AppCenter stay linked. The cuts below remove each path's starting point, and the UI that would reach it.

| Path | Cut |
| --- | --- |
| Sparkle | Delete `App.swift:564-575`, so `App.updaterController` stays nil. Every other use is optional-chained and becomes a no-op: `PreferencesEvents.swift:97-98`, `UserDefaultsEvents.swift:25-34`, `GeneralTab.swift:101-102`, `FeedbackWindow.swift:165,245`. Remove the updates rows (`GeneralTab.swift:24-26` and their layout) and the "Check for updates…" item (`Menubar.swift:40`). In `Info.plist`, delete `SUPublicEDKey` (61-62) and set `SUEnableAutomaticChecks` to false (63-64). |
| AppCenter | `App.swift:7` becomes `class App: NSApplication`. Delete `appCenterDelegate` (38) and its assignment (604). In `Info.plist`, set `NSPrincipalClass` to `NSApplication` (36-37) and delete the AppCenter keys (69-74). `App.shared.run()` (`main.swift:64`) is unaffected. |
| Licence server | Covered by decision 4. Delete `application(_:open:)` and `handleCustomUrl` (`App.swift:677-702`); their only job is licence activation. Remove the Upgrade entry in Settings (`SettingsWindow.swift:319`, `536-553`) and the Get Pro, My Account and Support this project menu items (`Menubar.swift:46-49`). |
| Feedback | Remove "Send feedback…" (`Menubar.swift:45`). The DEBUG-only `QaSurfaces.swift:398` may keep it. |

`scripts/meowtab/check_offline.sh` runs in CI and fails if any cut is undone. It checks:

- no `SPUStandardUpdaterController(` or `AppCenterCrash()` in `src/` outside `src/debug/`
- no call to `LicenseManager.shared.activate(` or `scheduleAsyncRevalidationIfNeeded()` (definitions are allowed)
- no `#selector(App.showFeedbackPanel)` or `#selector(App.checkForUpdatesNow)`
- in the built `Info.plist` (`PlistBuddy`): no `SUPublicEDKey`, `SUEnableAutomaticChecks` false, and `NSPrincipalClass` = `NSApplication`

### 4. Pro unlocked, in one file

`LicenseManager.swift` changes in three places:

- `private(set) var state: LicenseState = .pro` (61). This also covers anything that reads the state before `initialize()`, such as preference gating during `Preferences.initialize()`.
- `initialize()` (127-130) sets `state = .pro` and no longer schedules revalidation.
- `refreshState()` (135-138) leaves the state alone.

The rest of the file stays, so no code becomes unreachable. That matters because warnings are errors. Each line changed carries a `// MeowTab:` comment.

What `.pro` does elsewhere, with no edits needed:

- **Menubar:** `refreshLicenseMenuItems` would show My Account (`Menubar.swift:92-95`). Instead, decision 3 deletes the items at `:45-49` (Send feedback, Get Pro, My Account, Support this project). Its menu items then stay nil, so the function returns early at `:85` and never touches them.
- **Trial prompts:** suppressed by `ProTransitionManager.swift:212`.
- **Onboarding:** the trial announcement is nil outside `.trial` (`App.swift:246-249`).

Upstream's Pro and trial tests run on their testable kernels, not on `LicenseManager.shared`, so they keep passing.

### 5. Credit and GPL-3.0 compliance

- **README:** `README.md` is replaced by a MeowTab README. Its first section says:
  - MeowTab for Mac is a modified version of AltTab by Louis Pontoise and contributors;
  - links github.com/lwouis/alt-tab-macos and github.com/sponsors/lwouis;
  - thanks the author;
  - states GPL-3.0.
- **NOTICE.md (new):** names the upstream project and its base commit, says the fork was modified by tingtmu starting 2026-10, lists the modifications by change name, and states the licence. This satisfies the "prominent notices" of §5(a).
- **About window:**
  - "Source code" links the fork: `App.swift:17` becomes `https://github.com/tingtmu/mac_meowtab`.
  - A new "Based on AltTab" link points to upstream (`AboutTab.swift:10-16`).
  - The support button becomes "Sponsor AltTab's author" and opens github.com/sponsors/lwouis (`AboutTab.swift:39`, and `App.supportProject` at `App.swift:145-147`).
- **Kept as is:** `LICENCE.md` (CI checks it is identical to upstream's), the copyright string (`Info.plist:20-21`), and `docs/acknowledgments.md`. That file gains one line naming AltTab; it is bundled and shown in the app.
- **Corresponding Source (§6):** every binary links the exact tagged source. This is set up in `mac-preview-release`.

### 6. One CI workflow, no secrets

`.github/workflows/ci.yml` runs on push to `main`, on pull requests and on `workflow_dispatch`. Use the current major versions of `actions/checkout`, `upload-artifact` and `download-artifact`. Every job first runs `sudo xcode-select -s /Applications/Xcode_26.0.1.app`.

**`build` (macos-15):**
1. Write `config/local.xcconfig`:

```text
CODE_SIGN_IDENTITY = -
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM =
TEAM_ID =
OTHER_CODE_SIGN_FLAGS = --deep --options runtime
CURRENT_PROJECT_VERSION = <contents of MEOWTAB_VERSION>
APPCENTER_SECRET =
```

2. Build:

```text
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath DerivedData \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build
```

3. Check the built app:
   - `lipo -archs` prints both architectures;
   - `PlistBuddy` reads the bundle ID, name, version and `LSMinimumSystemVersion` = 12.0;
   - `codesign --verify --deep --strict` passes;
   - `bash scripts/meowtab/check_offline.sh` passes;
   - `git diff --exit-code 6d8940b5307d7348aaca70259c28147fc5ab00b3 -- LICENCE.md` passes.
4. Run `ditto -c -k --keepParent .../MeowTab.app MeowTab-<short sha>.zip`. `ditto` keeps the framework symlinks that `zip` would break. Upload the zip as an artifact.

**`test` (matrix: macos-15, macos-15-intel, macos-26):**
1. Write `sw_vers -productVersion`, `uname -m` and `xcodebuild -version` to the job summary.
2. Run `xcodebuild test -project alt-tab-macos.xcodeproj -scheme Test -configuration Release`, as upstream's `scripts/run_tests.sh` does. The `unit-tests` target's own xcconfigs disable signing, so this job needs no `local.xcconfig`.

**`launch` (needs `build`; matrix: macos-15, macos-15-intel):**
1. `sudo ditto -x -k` the artifact into `/Applications`, which avoids the Move-to-Applications prompt.
2. `open -n /Applications/MeowTab.app`, then wait 20 s.
3. Require all of the following:
   - `pgrep -x MeowTab` finds the process;
   - `lsof -nP -a -i -p <pid>` lists no internet sockets;
   - no `MeowTab*` crash report appears in `~/Library/Logs/DiagnosticReports`.
4. Quit the app.

Without permissions, the app stops at its permission screen. So this job proves that each slice starts and that the pre-permission phase is quiet. The static checks cover the paths that start after permissions are granted.

## Risks / Trade-offs

- **A cut fails at runtime and CI can't see it** (e.g. the superclass swap) → The launch job catches startup crashes on both architectures. The final real-Mac acceptance in `mac-preview-release` covers the rest.
- **Ad-hoc signatures change on every build, so macOS forgets Accessibility and Screen Recording grants** → Acceptable for CI artifacts. `mac-preview-release` signs with one stable identity.
- **Hidden upgrade surfaces in `.pro`** (e.g. a Pro badge leading to `SettingsWindow.swift:1322`) → Acceptance checks that no upgrade or account view can be reached. Any that is found is removed the same way as above.
- **Upstream moves on** → `main` is pinned. Merging a newer upstream tag is a separate, deliberate change.
- **No macOS 12–14 runtime evidence** → The README states the target (12.0+) apart from what was tested (CI: 15 on arm64 and Intel, 26 on arm64; plus the final real Mac).

## Open Questions

None blocking. Name and bundle ID can still be changed before the first public release.
