#!/usr/bin/env bash
# Imports the release signing certificate from the repository secrets into a new keychain that codesign can use.
# Why: openspec/changes/mac-preview-release/design.md decision 1. Usage, on a CI runner, with both secrets in the environment:
# MEOWTAB_CERT_P12=<base64 of codesign.p12> MEOWTAB_CERT_PASSWORD=<its password> bash scripts/meowtab/setup_release_signing.sh
#
# This script never prints either value and never traces itself (no set -x). Upstream's import script, called below,
# does run with set -x, so its trace shows the password (certificatePassword=... and security import ... -P ...).
# GitHub masks registered secrets in logs, so it shows as ***. The mask matches the value as printed, and the trace
# re-quotes a value holding a ' or a control character, so the password should be plain letters and digits.
set -euo pipefail
cd "$(dirname "$0")/../.."

missing=0
for name in MEOWTAB_CERT_P12 MEOWTAB_CERT_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "::error::$name is empty: it must be set as a repository secret and passed to this step (design.md decision 1)"
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 1

# The decoded file holds the private key: delete it when this script ends, even if the import fails.
trap 'rm -f codesign.p12' EXIT
printf '%s\n' "$MEOWTAB_CERT_P12" | base64 --decode > codesign.p12
bash scripts/codesign/import_certificate_into_new_keychain.sh codesign "$MEOWTAB_CERT_PASSWORD"

# Keep the new keychain unlocked for 6 hours, so it can't lock itself before Xcode signs at the end of a long build.
# GitHub's guide to signing on its runners does the same.
security set-keychain-settings -lut 21600 alt-tab-macos.keychain

# Without -v: the identity is self-signed, so macOS doesn't trust it, and -v would hide it.
security find-identity -p codesigning
