#!/usr/bin/env bash
# Removes MeowTab for Mac: its login item, the running app, its Accessibility and Screen Recording entries, the app,
# its data folder and its preferences, in that order. Why: openspec/changes/mac-easy-install/design.md decision 5.
# Usage, in Terminal (to read it first, end with "| less" instead of "| bash"):
#   curl -fsSL https://raw.githubusercontent.com/tingtmu/mac_meowtab/main/scripts/meowtab/uninstall.sh | bash
# Each part that is already gone is reported as "not found". To keep your pictures and settings, remove MeowTab by
# hand as the install guide's step 8 says. Only sudo can prompt (for tccutil); it reads the terminal, not the script.
# All code is in functions and `main "$@"` is the last line, so a download cut short runs nothing.
set -euo pipefail

ID=io.github.tingtmu.meowtab.macos
found=0
failed=0

removed() { echo "removed: $1"; found=1; }
not_found() { echo "not found: $1"; }
not_removed() { echo "uninstall.sh: could not remove $1" >&2; found=1; failed=1; }

remove_path() {
  if [ ! -e "$1" ]; then not_found "$1"; return 0; fi
  if rm -rf "$1"; then removed "$1"; else not_removed "$1"; fi
}

# Unloading the job also stops a copy that launchd started at login.
stop_login_item() {
  local target waited=0
  target=gui/$(id -u)/$ID
  if ! launchctl print "$target" >/dev/null 2>&1; then not_found "login item loaded in launchd"; return 0; fi
  # bootout can report an error while the job is still stopping, so check the outcome rather than its exit status.
  launchctl bootout "$target" 2>/dev/null || true
  while launchctl print "$target" >/dev/null 2>&1 && [ "$waited" -lt 10 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if launchctl print "$target" >/dev/null 2>&1; then
    not_removed "login item loaded in launchd ($target)"
  else
    removed "login item loaded in launchd"
  fi
}

# SIGTERM, not osascript's quit, which can raise macOS's Automation prompt (design.md decision 4).
quit_meowtab() {
  local waited=0
  if ! pgrep -U "$UID" -x MeowTab >/dev/null; then not_found "running MeowTab"; return 0; fi
  pkill -TERM -U "$UID" -x MeowTab || true
  while pgrep -U "$UID" -x MeowTab >/dev/null && [ "$waited" -lt 10 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if pkill -KILL -U "$UID" -x MeowTab; then sleep 1; fi
  if pgrep -U "$UID" -x MeowTab >/dev/null; then not_removed "running MeowTab (it didn't quit)"; else removed "running MeowTab (quit)"; fi
}

# Runs before the app is deleted: tccutil finds the bundle ID through LaunchServices, so it fails once the app is gone.
reset_permissions() {
  local service
  if [ ! -d /Applications/MeowTab.app ] && [ ! -d "$HOME/Applications/MeowTab.app" ]; then
    not_found "MeowTab.app, so its permissions can't be reset here; if MeowTab is still listed in System Settings > Privacy & Security > Accessibility (Device Control and Data Access on macOS 27) or Screen Recording, remove it there"
    return 0
  fi
  for service in Accessibility ScreenCapture; do
    if tccutil reset "$service" "$ID" >/dev/null 2>&1; then
      removed "$service permission"
      continue
    fi
    # Accessibility may live in the system TCC.db, which needs admin rights (design.md Risks).
    echo "tccutil reset $service needed sudo"
    if sudo tccutil reset "$service" "$ID" >/dev/null; then removed "$service permission"; else not_removed "$service permission"; fi
  done
}

delete_preferences() {
  local domain
  for domain in "$ID" "$ID.license" "$ID.usage"; do
    if ! defaults read "$domain" >/dev/null 2>&1; then not_found "preferences $domain"; continue; fi
    if defaults delete "$domain"; then removed "preferences $domain"; else not_removed "preferences $domain"; fi
  done
}

main() {
  if [ $# -ne 0 ]; then echo "usage: bash uninstall.sh" >&2; exit 1; fi
  stop_login_item
  quit_meowtab
  reset_permissions
  remove_path "$HOME/Library/LaunchAgents/$ID.plist"
  remove_path /Applications/MeowTab.app
  if [ -e "$HOME/Applications/MeowTab.app" ]; then remove_path "$HOME/Applications/MeowTab.app"; fi
  remove_path "$HOME/Library/Application Support/MeowTab"
  delete_preferences

  if [ "$failed" -ne 0 ]; then
    echo "uninstall.sh: some of MeowTab could not be removed; see the messages above" >&2
    exit 1
  fi
  if [ "$found" -eq 0 ]; then
    echo "Nothing of MeowTab was found; nothing to remove."
  else
    echo "MeowTab is removed."
  fi
}

main "$@"
