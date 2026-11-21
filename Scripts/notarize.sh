#!/bin/zsh
# Builds, signs with Developer ID, notarizes and staples Lidless, then writes build/Lidless-<version>.zip.
#
# One-time setup:
#   1. A "Developer ID Application" certificate in your keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application).
#   2. Notary credentials stored in the keychain:
#      xcrun notarytool store-credentials lidless-notary --apple-id <your Apple ID> --team-id <TEAM ID>
#      (it asks for an app-specific password from account.apple.com)
#
# NOTARY_PROFILE overrides the keychain profile name (default: lidless-notary).
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
PROFILE="${NOTARY_PROFILE:-lidless-notary}"
VERSION="$(cat VERSION)"

IDENTITY="$(security find-identity -v -p codesigning | grep -m1 'Developer ID Application' | sed -E 's/.*"(.*)"/\1/' || true)"
if [[ -z "$IDENTITY" ]]; then
  echo "No Developer ID Application certificate found. See the setup notes at the top of this script." >&2
  exit 1
fi

SIGN_IDENTITY="$IDENTITY" ./Scripts/build-app.sh

ZIP="build/Lidless-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Lidless.app "$ZIP"

xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple build/Lidless.app
xcrun stapler validate build/Lidless.app
spctl --assess --type execute --verbose build/Lidless.app

# Re-zip so the download carries the stapled ticket.
rm -f "$ZIP"
ditto -c -k --keepParent build/Lidless.app "$ZIP"
shasum -a 256 "$ZIP"
echo "Ready: $ZIP"
