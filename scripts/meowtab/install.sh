#!/usr/bin/env bash
# Installs or updates MeowTab for Mac as /Applications/MeowTab.app from the project's GitHub releases, then opens it.
# Why: openspec/changes/mac-easy-install/design.md decisions 1-4. Usage, in Terminal (to read it first, end with
# "| less" instead of "| bash"):
#   curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh | bash -s -- v0.1.0-rc.1
# Without a tag it installs the newest release that isn't a pre-release; with one, that release.
#
# Nothing is replaced until the zip's SHA-256, the app's signature and its designated requirement all check out
# (decision 3). It never changes quarantine attributes, Gatekeeper or SIP.
# All code is in functions and `main "$@"` is the last line, so a download cut short runs nothing (decision 1).
set -euo pipefail

SCRIPT_URL=https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/install.sh
# Must equal docs/designated-requirement.txt byte for byte; CI checks it.
REQUIREMENT='designated => identifier "io.github.tingtmu.meowtab.macos" and certificate leaf = H"415685b6efeaeaadb016e15b3d09887b5ae5999e"'
TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$'
SUMS_RE='^[0-9a-f]{64}  ([^[:space:]]+)$'
ZIP_RE='^MeowTab-v[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?-mac\.zip$'
APPS=/Applications

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

# fetch <url> <file> [message if the server says 404]
fetch() {
  local code
  code=$(curl -fsSL -o "$2" -w '%{http_code}' "$1") && return
  if [ "$code" = 404 ] && [ -n "${3:-}" ]; then fail "$3"; fi
  fail "could not download $1"
}

# Downloads SHA256SUMS.txt and the zip it names into $tmp. Sets zip, and tag when none was given (decision 2).
download() {
  local base=$1 url sums no_release=
  if [ -n "$tag" ]; then
    url=$base/download/$tag
  else
    # GitHub's "latest" skips pre-releases, so it is 404 until a full release exists.
    url=$base/latest/download
    no_release="no published release yet (only pre-releases?); pass a tag, e.g.: curl -fsSL $SCRIPT_URL | bash -s -- v0.1.0-rc.1"
  fi
  fetch "$url/SHA256SUMS.txt" "$tmp/SHA256SUMS.txt" "$no_release"

  # Names come from the server, so check them before they go into a URL or a path.
  sums=$(<"$tmp/SHA256SUMS.txt")
  [[ $sums =~ $SUMS_RE ]] || fail "SHA256SUMS.txt isn't one '<sha256>  <zip>' line"
  zip=${BASH_REMATCH[1]}
  [[ $zip =~ $ZIP_RE ]] || fail "SHA256SUMS.txt names a file that isn't a MeowTab release zip"
  if [ -z "$tag" ]; then
    tag=${zip#MeowTab-}
    tag=${tag%-mac.zip}
    # Pinned, in case "latest" moves to a newer release between the two downloads.
    url=$base/download/$tag
  elif [ "$zip" != "MeowTab-$tag-mac.zip" ]; then
    fail "SHA256SUMS.txt names $zip, not MeowTab-$tag-mac.zip"
  fi

  echo "Downloading MeowTab $tag..."
  fetch "$url/$zip" "$tmp/$zip"
}

# Checks the download before anything is replaced (decision 3). Sets app.
verify() {
  local actual entries entry
  (cd "$tmp" && shasum -a 256 -c SHA256SUMS.txt >/dev/null) || fail "the SHA-256 of $zip doesn't match SHA256SUMS.txt"
  # The hash doesn't prove the zip is ours, so before unpacking, make sure nothing in it lands outside MeowTab-<tag>/.
  # release.yml zips with --sequesterRsrc, which keeps extended attributes under __MACOSX/; ditto applies those as metadata.
  entries=$(zipinfo -1 "$tmp/$zip") || fail "could not list the files in $zip"
  while IFS= read -r entry; do
    case $entry in
      "MeowTab-$tag/"* | __MACOSX/ | "__MACOSX/MeowTab-$tag/"*) ;;
      *) fail "the zip holds a path outside MeowTab-$tag/; refusing to unpack it" ;;
    esac
    [[ "/$entry/" != */../* ]] || fail "the zip holds a path outside MeowTab-$tag/; refusing to unpack it"
  done <<<"$entries"
  ditto -x -k "$tmp/$zip" "$tmp" || fail "could not unpack $zip"
  app=$tmp/MeowTab-$tag/MeowTab.app
  [ -d "$app" ] || fail "$zip doesn't hold MeowTab-$tag/MeowTab.app"
  codesign --verify --deep --strict "$app" || fail "the app's signature doesn't verify"
  # The hash only shows the zip arrived intact; this ties the app to the project's certificate. Compared as
  # release.yml's "Check the designated requirement" step does: codesign's whole stdout.
  actual=$(codesign -d -r- "$app" 2>/dev/null) || true
  [ "$actual" = "$REQUIREMENT" ] || fail "the app's designated requirement isn't MeowTab's; it is: ${actual:-none}"
  echo "Checked the SHA-256, the signature and the designated requirement."
}

# SIGTERM, not osascript's quit, which can raise macOS's Automation prompt (decision 4).
quit_meowtab() {
  local waited=0
  pkill -TERM -U "$UID" -x MeowTab || return 0
  echo "Quitting MeowTab..."
  while pgrep -U "$UID" -x MeowTab >/dev/null && [ "$waited" -lt 10 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if pkill -KILL -U "$UID" -x MeowTab; then sleep 1; fi
}

# Copies, then swaps by renaming, so a failure partway leaves a whole app in place, never a mix (decision 4).
install_app() {
  local dest=$APPS/MeowTab.app new=$APPS/.MeowTab.app.new old=$APPS/.MeowTab.app.old
  [ -w "$APPS" ] || fail "can't write to $APPS; install from an administrator account"
  quit_meowtab
  rm -rf "$new" "$old" || fail "could not remove $new or $old, left by an earlier run"
  ditto "$app" "$new" || fail "could not copy the app to $new"
  if [ -e "$dest" ]; then
    mv "$dest" "$old" || fail "could not move the old app aside to $old"
  fi
  if ! mv "$new" "$dest"; then
    if [ -e "$old" ]; then mv "$old" "$dest" || true; fi
    fail "could not move the new app into $dest"
  fi
  rm -rf "$old" || echo "install.sh: could not remove the old app at $old; delete it by hand" >&2
  open "$dest" || fail "installed $dest, but could not open it"
}

main() {
  [ $# -le 1 ] || fail "usage: bash install.sh [tag]"
  tag=${1:-}
  if [ -n "$tag" ] && ! [[ $tag =~ $TAG_RE ]]; then
    fail "not a release tag: $tag (expected one like v0.1.0 or v0.1.0-rc.1)"
  fi
  tmp=$(mktemp -d) || fail "could not create a temporary folder"
  trap 'rm -rf "$tmp"' EXIT

  download "${MEOWTAB_RELEASES_URL:-https://github.com/tingtmu/mac_meowtab/releases}"
  verify
  install_app
  echo "MeowTab $tag is installed and open. Grant its permissions when it asks (install guide, step 4)."
}

main "$@"
