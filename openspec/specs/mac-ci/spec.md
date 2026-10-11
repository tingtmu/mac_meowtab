# mac-ci Specification

## Purpose
How MeowTab for Mac is built and tested without a Mac or any secret: GitHub-hosted runners for both processor families, and honest reporting of what was actually run.

## Requirements

### Requirement: Universal build without secrets
Every push to `main` and every pull request SHALL build a universal (arm64 and x86_64), ad-hoc-signed Release app on `macos-15` with Xcode 26.0.1, using no repository secrets. The build SHALL be uploaded as a zip artifact made with `ditto`.

#### Scenario: A pull request from a fork
- **WHEN** CI runs for a pull request, which has no access to secrets
- **THEN** the build succeeds, `lipo -archs` lists `x86_64 arm64`, and `codesign --verify --deep --strict` passes

### Requirement: Unit tests on both processor families
Upstream's `Test` scheme, and every test added later, SHALL run on `macos-15` (arm64), `macos-15-intel` (x64) and `macos-26` (arm64). A failing test SHALL fail the workflow.

#### Scenario: A test fails on Intel only
- **WHEN** a test passes on `macos-15` but fails on `macos-15-intel`
- **THEN** the workflow fails and names the Intel job

### Requirement: Launch check
After the build, CI SHALL install the artifact in `/Applications` on `macos-15` and `macos-15-intel` and launch it. It SHALL fail if, after 20 s, the process is not running, holds an internet socket, or has written a crash report.

#### Scenario: Startup crash
- **WHEN** a change makes the app crash at launch
- **THEN** the launch job fails on the affected architecture

### Requirement: Honest coverage
Each test job SHALL write its macOS version, architecture and Xcode version to the job summary. The README SHALL keep the deployment target (macOS 12.0) separate from the versions actually tested, and SHALL name macOS 12–14 as targeted but not tested by CI.

#### Scenario: Reading the README's compatibility section
- **WHEN** a user checks whether MeowTab supports macOS 13
- **THEN** the README says it is targeted (12.0+) but not tested, and lists the versions CI ran on
