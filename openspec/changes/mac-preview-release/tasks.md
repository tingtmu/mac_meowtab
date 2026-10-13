# Tasks

Starts after `mac-png-peek` is archived. Groups 1–3 are checked by CI and by reading. Group 4 depends on the tester and may loop through several candidates. Group 5 runs only after a candidate is accepted.

## 1. Signing identity

- [x] 1.1 Add the optional third argument (`CN`, default `Local Self-Signed`) and fourth argument (validity in days, default 30, openssl's own default) to `scripts/codesign/generate_selfsigned_certificate.sh`. Verify: `bash -n` passes; with two arguments the generated `.conf` is byte-identical to upstream's and the certificate lasts 30 days; with `"MeowTab for Mac" 3650` its CN is `MeowTab for Mac` and it lasts 10 years.
- [x] 1.2 **Owner only; no agent handles the password.** Generate the certificate and set the two secrets (design.md 1). Verify: `gh secret list` shows `MEOWTAB_CERT_P12` and `MEOWTAB_CERT_PASSWORD`, and no `codesign.*` file is tracked (`git status`).
- [ ] 1.3 Add `scripts/meowtab/setup_release_signing.sh` (design.md 1). Verify: through task 2.2's dry run.

## 2. Build script and release workflow

- [x] 2.1 Move the `build` job's steps into `scripts/meowtab/build.sh <identity>`, have `ci.yml` call it with `-`, and add `on: workflow_call` to `ci.yml`. Verify: CI on `main` is green with the same checks as before.
- [ ] 2.2 Add `.github/workflows/release.yml` and `docs/release-notes-template.md` (design.md 2). Verify, with a `workflow_dispatch` dry run:
  - the signed zip and `SHA256SUMS.txt` arrive as artifacts;
  - the log prints the designated requirement; commit it as `docs/designated-requirement.txt`;
  - a second dry run passes the requirement check.

  Push a throwaway tag `v9.9.9-rc.1`. Verify that it fails at the version check and creates no release, then delete the tag.

## 3. Guides

- [x] 3.1 Write `docs/install.md` (design.md 3), and add Install and Download sections to the README that link it. Verify by reading it against the `mac-release` "Install guide" requirement: each listed topic appears, there is no Gatekeeper or SIP disabling, and the commands are copied exactly from design.md.
- [x] 3.2 Finish `docs/acceptance.md` as the run sheet of design.md 4. Verify with a cross-check table at the end of the sheet: each scenario of every spec in `openspec/specs/` is listed as either "unit test: <test name>", "CI: <job>" or "row <n>", with none missing.

## 4. Candidates and acceptance

- [ ] 4.1 Tag `v0.1.0-rc.1`. Publish the draft as a pre-release, keeping its "Test candidate" label. Send the tester the release link, `INSTALL.md` and the run sheet. Verify: a fresh download's SHA-256 matches `SHA256SUMS.txt` and the notes.
- [ ] 4.2 Record the tester's results as `docs/acceptance/v0.1.0-rc.1.md` (design.md 4). For each Fail:
  - fix it on `main`, adding a unit test whenever the cause is in tested logic;
  - tag the next `rc`;
  - repeat this task for that `rc`, with the "update without re-granting" row from `rc.2` on.

  Verify: each record has no blank row, and gives the macOS version, the chip and the timing output.

## 5. Preview

- [ ] 5.1 Promote the accepted candidate (design.md 5). Switch the README's quick start to the download and add any privacy-safe screenshots. Verify:
  - `v0.1.0`'s zip hash equals the accepted `rc`'s;
  - the notes link the record, list the "Not tested" rows, and credit AltTab with both links.
- [ ] 5.2 Update `ROADMAP.md` (the MVP is done; next are the trimming change and GIF support) and archive this change (`openspec archive mac-preview-release`). Verify: `openspec list` shows no open MVP change.
