# Design

## Context

See [proposal.md](proposal.md). After `mac-png-peek`, CI builds an ad-hoc-signed universal app, runs the unit tests on three runners, and launches the app on two. `docs/acceptance.md` lists every check that CI can't make. Facts this design relies on (checked 2026-10-11):

- **Gatekeeper.** On macOS 15 and 26, Control-click > Open no longer bypasses Gatekeeper. The user opens the app once, then clicks System Settings > Privacy & Security > Open Anyway, available for about an hour, and enters their password. macOS 14 still allows Control-click > Open.
  - https://developer.apple.com/news/?id=saqachfa
  - https://support.apple.com/guide/mac-help/mh40616/15.0/mac/15.0
- **Permission grants follow the designated requirement.** An ad-hoc signature's requirement is tied to one build, so every update loses the grants. A stable certificate gives a stable requirement (`identifier "…" and certificate leaf = H"…"`). Upstream relies on this for local builds ("Local Self-Signed"). That grants survive updates in practice is checked in acceptance.
  - https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements
- **Upstream scripts.**
  - `scripts/codesign/generate_selfsigned_certificate.sh` makes a code-signing certificate with openssl, adding `-legacy` for OpenSSL 3.
  - `import_certificate_into_new_keychain.sh` imports a `.p12` into a temporary keychain that `codesign` can use.
  - Upstream's pull-request CI already signs this way with an untrusted self-signed identity (`setup_ci_pr.sh`).
  - `.gitignore` already ignores `codesign.{conf,crt,key,p12}`.
- **Homebrew** will disable casks that fail Gatekeeper checks (https://brew.sh/2025/11/12/homebrew-5.0.0/).

## Goals / Non-Goals

**Goals:**

- Testers and users get an honest, checkable download that keeps its permission grants through updates.
- The preview ships exactly what was accepted on a real Mac.

**Non-Goals:** notarization, Developer ID, Homebrew, automatic updates, and translated guides.

## Decisions

### 1. The signing identity

The owner does this once, on Windows in Git Bash. An agent must not see or handle the password.

```text
bash scripts/codesign/generate_selfsigned_certificate.sh codesign "<password>" "MeowTab for Mac" 3650
base64 -w0 codesign.p12 | gh secret set MEOWTAB_CERT_P12
gh secret set MEOWTAB_CERT_PASSWORD        # type the password at the prompt
```

- The script's new third argument sets `CN`. It defaults to `Local Self-Signed`, so upstream's callers are unaffected.
- The new fourth argument sets the validity in days. Its default is openssl's own, 30 days, which suits upstream's throwaway local certificates. The release certificate must outlast many releases, so it gets 10 years.
- Keep `codesign.p12` and the password in a password manager, then delete the local `codesign.*` files.
- **Losing the certificate** means the next release has a new requirement, so users must re-grant permissions once. The install guide says so.

In CI, `scripts/meowtab/setup_release_signing.sh`:

1. decodes `MEOWTAB_CERT_P12` into `codesign.p12`;
2. runs `scripts/codesign/import_certificate_into_new_keychain.sh codesign "$MEOWTAB_CERT_PASSWORD"`.

The release build's `config/local.xcconfig` sets:

```text
CODE_SIGN_IDENTITY = MeowTab for Mac
OTHER_CODE_SIGN_FLAGS = --timestamp=none --deep --options runtime
```

The rest is as in CI. `--timestamp=none` matches upstream's self-signed builds (`config/debug.xcconfig:8`).

After signing, the requirement is checked:

- **Command.** `codesign -d -r- MeowTab.app` must print exactly the requirement committed in `docs/designated-requirement.txt`.
- **First run.** The first signed run prints it; commit it then. Every later run compares against it.

### 2. One build script, two workflows

- **`scripts/meowtab/build.sh <signing identity>`** holds the CI `build` job's steps, in their old order: compare `LICENCE.md`, select Xcode, write `config/local.xcconfig`, run `xcodebuild`, check the bundle (architectures, signature, identity), run the offline checks, and check the bundled pictures. `ci.yml` calls it with `-`.
- **`ci.yml`** gains `on: workflow_call`, so the release workflow reuses its build, test and launch jobs unchanged. Its `screenshot` job also requires `github.workflow == 'CI'`. In a called workflow the `github` context is the caller's, so a dry run, which is a `workflow_dispatch` too, would otherwise run it.
- **`.github/workflows/release.yml`** runs on tags `v*` and on `workflow_dispatch` (a dry run with no release). Only `package` gets `permissions: contents: write`; the other jobs read. Its jobs:
  1. **`version` (ubuntu):** the version check, first, so a bad tag fails before anything is built. The tag must be `vX.Y.Z` or `vX.Y.Z-rc.N`, and `X.Y.Z` must equal `MEOWTAB_VERSION`. `CFBundleShortVersionString` stays `X.Y.Z`; the `rc` suffix appears only in the tag and the file names. A dry run needs `MEOWTAB_VERSION` to be `X.Y.Z`, and uses the name `vX.Y.Z-dry-run-<short commit>` in place of the tag below.
  2. **`ci` (needs `version`):** `uses: ./.github/workflows/ci.yml`. A failing test or launch stops the release.
  3. **`package` (macos-15, needs both):**
     1. On a tag that already has a published release, it stops here and succeeds (decision 5).
     2. `setup_release_signing.sh`, then `build.sh "MeowTab for Mac"`.
     3. The requirement check of decision 1, then `codesign --verify --deep --strict`. Until `docs/designated-requirement.txt` is committed, a dry run warns and goes on, and a tag fails.
     4. Copy `MeowTab.app` (with `ditto`, then verify the copy's signature), `LICENCE.md`, `NOTICE.md` and `docs/install.md` (as `INSTALL.md`) into a folder `MeowTab-<tag>/`. Run `ditto -c -k --sequesterRsrc --keepParent MeowTab-<tag> MeowTab-<tag>-mac.zip`, so unzipping gives that folder. Run `shasum -a 256 MeowTab-<tag>-mac.zip > SHA256SUMS.txt`.
     5. On a tag: `gh release create <tag> --draft --prerelease --verify-tag --title "MeowTab for Mac <tag>" --notes-file notes.md MeowTab-<tag>-mac.zip SHA256SUMS.txt`. On a dry run: upload the zip, `SHA256SUMS.txt` and `notes.md` as one artifact.
- **Release notes** come from `docs/release-notes-template.md`, filled by the workflow. They contain:
  - the label: "Test candidate — not yet checked on a real Mac" for an `rc`, "Preview" for `v0.1.0`, and "Dry run — not a release" for a dry run;
  - the SHA-256 of the zip;
  - the source, as a link to the exact tag. This is the Corresponding Source of GPL-3.0 §6; GitHub also attaches source archives;
  - signing: "Self-signed, not notarized. macOS asks once on first open; see INSTALL.md.";
  - compatibility: target macOS 12.0+ on Apple silicon and Intel; the CI runtimes of this run; the real-Mac record, if any; "macOS 12–14 not tested";
  - credit: "Based on AltTab by Louis Pontoise and contributors", with the upstream and sponsor links.

### 3. The install guide (`docs/install.md`)

Short, numbered steps:

1. Download `MeowTab-<version>-mac.zip`. Optionally check it with `shasum -a 256`.
2. Unzip it, and move `MeowTab.app` to Applications.
3. Open it the first time:
   - **macOS 15 and 26:** open MeowTab, close the warning, then go to System Settings > Privacy & Security, click Open Anyway within the hour, and enter your password.
   - **macOS 14 and earlier:** Control-click MeowTab > Open.
4. Grant Accessibility (required). Grant Screen Recording, or skip it to get app icons instead of previews.
5. If AltTab is installed, quit it, or give one of the two apps other shortcuts. Both use ⌥⇥, and ⌥ with the key above Tab.
6. MeowTab starts at login by default; turn this off in Settings > General.
7. **Updating:** quit MeowTab and replace the app. Permission grants and pictures carry over. The new copy is a new download, so its first open may need step 3 again. If macOS asks for the permissions again, which happens only after a signing-certificate change, remove MeowTab from the permission list and add it again.
8. **Removing:** turn off start at login (step 6; that removes the login item), quit MeowTab, delete the app, and optionally its data: `rm -r ~/Library/Application\ Support/MeowTab`, then `defaults delete io.github.tingtmu.meowtab.macos`.

The guide never suggests disabling Gatekeeper or SIP, nor `spctl --master-disable`.

### 4. The acceptance run

`docs/acceptance.md` becomes a run sheet.

- **Header:** date, candidate tag, macOS version (`sw_vers`), chip (Apple menu > About This Mac), displays and their scales, and whether AltTab or another switcher is installed.
- **Rows**, one per manual scenario, each with Pass, Fail or "Not tested — reason", and notes:
  - **Install and permissions:** first open per the guide; Accessibility; skipping Screen Recording.
  - **Switching basics (upstream behaviour, smoke-tested):** ⌥⇥, ⇧, release, Esc, click, and closing a window that has unsaved changes.
  - **Everything gathered by the first two changes:** About, sponsor link, coexisting with AltTab, no upgrade prompts, the peek scenarios and the settings scenarios.
  - **Updating** from the previous `rc` without re-granting (from `rc.2` on).
- **Timing:** run `log stream --level debug --predicate 'category == "peek"'` in Terminal, open the switcher 20 times with about 10 windows, and paste the output.
- **Privacy:** screenshots show only demo windows (empty TextEdit or Finder windows) over a plain desktop picture.

The owner copies the tester's results into `docs/acceptance/<tag>.md`. The tested OS and chip are evidence; they don't narrow the macOS 12.0+ target.

### 5. The preview gate

The preview is promoted from an accepted `rc` without rebuilding, so users get the bytes that were tested:

```text
gh release download v0.1.0-rc.N -D rc
git tag v0.1.0 <commit of v0.1.0-rc.N> && git push origin v0.1.0
cp rc/MeowTab-v0.1.0-rc.N-mac.zip MeowTab-v0.1.0-mac.zip
shasum -a 256 MeowTab-v0.1.0-mac.zip > SHA256SUMS.txt     # same hash as the rc
gh release create v0.1.0 --prerelease --title "MeowTab for Mac 0.1.0 (preview)" \
  --notes-file notes.md MeowTab-v0.1.0-mac.zip SHA256SUMS.txt
```

- **Tag push.** Pushing `v0.1.0` also triggers `release.yml`. Its `package` job starts only after CI, when the release above exists, so it skips the tag without building. If the release comes later than that, the workflow makes a draft, which is deleted unused.
- **Notes** link `docs/acceptance/v0.1.0-rc.N.md`.
- **README:** the Quick start switches to the download link and the install guide.

**Screenshots** for the README come from the CI screenshot job, if `mac-png-peek` task 4.3 worked; runners hold no personal data. Otherwise they come from the tester, following the privacy rule above.

## Risks / Trade-offs

- **Grants still lost on update despite the stable certificate** → Acceptance checks it from `rc.2` on. If it happens, the install guide documents re-granting, and Developer ID becomes the next roadmap item.
- **The tester struggles with Open Anyway** → The guide uses Apple's own wording and steps; the rows record where it got stuck.
- **A failure found by the tester can't be reproduced on CI** → Fix it with a unit test where the logic allows, otherwise by reasoning plus the next `rc` run. Every candidate tag is a full CI run.
- **Equipment gaps** (one display, no Intel Mac, no fullscreen apps) → "Not tested" rows stay in the record and the release notes; they are never counted as passes.
