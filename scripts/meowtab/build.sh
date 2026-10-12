#!/usr/bin/env bash
# Checks the licence, builds the universal Release app at DerivedData/Build/Products/Release/MeowTab.app signed with the
# given identity, and checks the app: architectures and signature, identity, offline cuts, bundled pictures.
# Why one script: openspec/changes/mac-preview-release/design.md decision 2 (ci.yml signs ad hoc; release.yml signs with
# the release identity, decision 1). Usage, on a GitHub macOS runner, as it switches Xcode with sudo:
# bash scripts/meowtab/build.sh <signing identity>, where - signs ad hoc.
set -euo pipefail
cd "$(dirname "$0")/../.."

if [ $# -ne 1 ] || [ -z "$1" ]; then
  echo "usage: bash scripts/meowtab/build.sh <signing identity>, where - signs ad hoc" >&2
  exit 1
fi
identity=$1
APP=DerivedData/Build/Products/Release/MeowTab.app

echo "--- Check licence unchanged ---"
git fetch --no-tags --depth=1 origin 6d8940b5307d7348aaca70259c28147fc5ab00b3
git diff --exit-code FETCH_HEAD -- LICENCE.md

echo "--- Select Xcode 26.0.1 ---"
sudo xcode-select -s /Applications/Xcode_26.0.1.app

echo "--- Write config/local.xcconfig ---"
version=$(tr -d '[:space:]' < MEOWTAB_VERSION)
if [ "$identity" = - ]; then
  sign_flags="--deep --options runtime"
else
  # A self-signed identity gets no secure timestamp, as in upstream's config/debug.xcconfig (design.md decision 1).
  sign_flags="--timestamp=none --deep --options runtime"
fi
cat > config/local.xcconfig <<EOF
CODE_SIGN_IDENTITY = $identity
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM =
TEAM_ID =
OTHER_CODE_SIGN_FLAGS = $sign_flags
CURRENT_PROJECT_VERSION = $version
EOF

echo "--- Build ---"
xcodebuild -project alt-tab-macos.xcodeproj -scheme Release -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath DerivedData \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build

echo "--- Check architectures and signature ---"
archs=" $(lipo -archs "$APP/Contents/MacOS/$(basename "$APP" .app)") "
echo "archs:$archs"
[[ "$archs" == *" arm64 "* && "$archs" == *" x86_64 "* ]] || { echo "::error::expected arm64 and x86_64"; exit 1; }
codesign --verify --deep --strict --verbose=2 "$APP"

echo "--- Check identity ---"
plist="$APP/Contents/Info.plist"
expected_version=$(tr -d '[:space:]' < MEOWTAB_VERSION)
status=0
check() {
  actual=$(/usr/libexec/PlistBuddy -c "Print :$1" "$plist" || true)
  echo "$1 = $actual"
  if [ "$actual" != "$2" ]; then
    echo "::error::$1 is '$actual', expected '$2'"
    status=1
  fi
}
check CFBundleIdentifier io.github.tingtmu.meowtab.macos
check CFBundleName MeowTab
check CFBundleShortVersionString "$expected_version"
check LSMinimumSystemVersion 12.0
[ "$status" -eq 0 ] || exit 1

echo "--- Check offline cuts ---"
bash scripts/meowtab/check_offline.sh "$APP/Contents/Info.plist"

echo "--- Check bundled pictures ---"
# Byte-identical copies of Windows MeowTab's images/chill_*.png at commit ed4602f.
cd "$APP/Contents/Resources"
ls -l chill_few.png chill_some.png chill_many.png
shasum -a 256 -c <<'EOF'
a229aab81213bfb825f0772b9cc146e5464d7037687a30fd5c77fd317ab80e3e  chill_few.png
252ba163c7ea068ed5e7248c712e5d283f84c69a61bf5ef5ec381634d0b05529  chill_some.png
8f8fb5496462d48c83289e3f47f6a9f6dd53905146c8ea8235b642f7058095c0  chill_many.png
EOF
