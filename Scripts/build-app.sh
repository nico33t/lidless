#!/bin/zsh
# Builds Lidless.app into ./build.
# SIGN_IDENTITY: codesigning identity (default: first "Developer ID Application", else "Apple Development", else ad hoc).
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/Lidless.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Lidless"

rm -rf "$APP"
# Keep build copies out of Spotlight so they never show up next to the installed app.
mkdir -p build && touch build/.metadata_never_index
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Lidless"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/" \
  && /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep -m1 'Developer ID Application' | sed -E 's/.*"(.*)"/\1/' || true)"
  [[ -z "$SIGN_IDENTITY" ]] && SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep -m1 'Apple Development' | sed -E 's/.*"(.*)"/\1/' || true)"
  [[ -z "$SIGN_IDENTITY" ]] && SIGN_IDENTITY="-"
fi

# Notarization needs a secure timestamp; local builds skip it to work offline.
TIMESTAMP="--timestamp=none"
[[ "$SIGN_IDENTITY" == Developer\ ID* ]] && TIMESTAMP="--timestamp"
codesign --force --options runtime "$TIMESTAMP" --entitlements Resources/Lidless.entitlements \
  --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP ($VERSION, build $BUILD)"
