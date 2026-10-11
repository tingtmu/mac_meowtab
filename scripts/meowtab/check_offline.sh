#!/usr/bin/env bash
# Guards MeowTab's offline cuts (no updater, crash reports, licence server, feedback or licence menu items) against being undone.
# What it checks and why: openspec/changes/archive/2026-10-11-mac-fork-baseline/design.md section 3. Usage: bash scripts/meowtab/check_offline.sh [built/Info.plist]
set -u
cd "$(dirname "$0")/../.." || exit 1
status=0

fail() { echo "::error::$1"; status=1; }

# forbid <check> <fixed string> <path>...: fails on each match, except under src/debug/.
forbid() {
  name=$1; pat=$2; shift 2
  hits=$(grep -rnHF -e "$pat" "$@" | grep -v '^src/debug/')
  [ -n "$hits" ] || return 0
  status=1
  printf '%s\n' "$hits" | while IFS= read -r hit; do
    rest=${hit#*:}
    echo "::error::$name: found '$pat' at ${hit%%:*}:${rest%%:*}"
  done
}

# require <check> <fixed string> <file>
require() {
  grep -nF -e "$2" "$3" >/dev/null || fail "$1: '$2' is missing from $3"
}

forbid "no Sparkle updater" 'SPUStandardUpdaterController(' src
forbid "no AppCenter crash reporting" 'AppCenterCrash()' src

lic=src/pro/license/LicenseManager.swift
require "Pro unlocked" 'return ProLicenseManager(' $lic
require "no licence revalidation" 'override func scheduleAsyncRevalidationIfNeeded() {}' $lic

forbid "no licence URL handler" 'handleCustomUrl' src/App.swift
# App.shared.activate(ignoringOtherApps:) is fine; any other .activate( is the licence activation.
hits=$(grep -nF '.activate(' src/App.swift | grep -v 'ignoringOtherApps')
if [ -n "$hits" ]; then
  status=1
  printf '%s\n' "$hits" | while IFS= read -r hit; do
    echo "::error::no licence activation: found '.activate(' at src/App.swift:${hit%%:*}"
  done
fi

forbid "no Upgrade button" 'upgradeButtonClicked' src/preferences/settings-window/SettingsWindow.swift
forbid "no update check" 'checkForUpdatesNow' src

menubar=src/Menubar.swift
forbid "no feedback menu item" 'App.showFeedbackPanel' $menubar
# The strings are matched as menu item titles: the unused UpgradeMenuItemView still draws "Get Pro".
for title in 'Check for updates…' 'Get Pro' 'My Account' 'Support this project'; do
  forbid "no '$title' menu item" "addMenuItem(NSLocalizedString(\"$title\"" $menubar
done

if [ $# -gt 0 ]; then
  plist=$1
  pb=/usr/libexec/PlistBuddy
  for key in SUPublicEDKey AppCenterSecret; do
    if "$pb" -c "Print :$key" "$plist" >/dev/null 2>&1; then
      fail "plist: $key is present in $plist"
    else
      echo "$key absent"
    fi
  done
  for pair in SUEnableAutomaticChecks=false NSPrincipalClass=NSApplication; do
    key=${pair%%=*}; want=${pair#*=}
    got=$("$pb" -c "Print :$key" "$plist" 2>/dev/null || true)
    echo "$key = $got"
    [ "$got" = "$want" ] || fail "plist: $key is '$got', expected '$want' in $plist"
  done
fi

[ "$status" -eq 0 ] || exit 1
echo "check_offline: OK (source checks${1:+ and plist checks})"
