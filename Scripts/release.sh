#!/bin/zsh
#
# Builds, signs, notarizes, and staples a HubDrop release for direct
# distribution outside the Mac App Store.
#
# One-time setup:
#
#   1. A "Developer ID Application" certificate for team 8D2X524S6C must be in
#      the login keychain. Xcode > Settings > Accounts > Manage Certificates
#      creates one if needed.
#
#   2. Store notarization credentials in the keychain under a profile name.
#      Either an app-specific password from account.apple.com:
#
#         xcrun notarytool store-credentials HubDrop \
#             --apple-id you@example.com --team-id 8D2X524S6C
#
#      or an App Store Connect API key with the Developer role:
#
#         xcrun notarytool store-credentials HubDrop \
#             --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>
#
# Usage:
#
#   Scripts/release.sh [--skip-notarization] [keychain-profile]
#
#   The profile defaults to "HubDrop". --skip-notarization stops after the
#   signed export, which is useful for checking that signing works.
#
# Output:
#
#   build/release/HubDrop-<version>.zip   notarized, stapled, ready to upload
#   build/release/HubDrop.xcarchive       keep this for the dSYM
#
# The Release configuration still signs with "Apple Development" for local
# runs. The export step re-signs the archived app with Developer ID, so no
# project settings change between development and release builds.

set -euo pipefail

NOTARIZE=1
PROFILE="HubDrop"
for arg in "$@"; do
    case "$arg" in
        --skip-notarization) NOTARIZE=0 ;;
        -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) PROFILE="$arg" ;;
    esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/release"
ARCHIVE="$BUILD/HubDrop.xcarchive"
EXPORT="$BUILD/export"
APP="$EXPORT/HubDrop.app"

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "==> Archiving Release build"
xcodebuild archive \
    -project "$ROOT/HubDrop.xcodeproj" \
    -scheme HubDrop \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE" \
    -quiet

echo "==> Exporting with Developer ID"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$ROOT/Scripts/ExportOptions.plist" \
    -exportPath "$EXPORT" \
    -quiet

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ZIP="$BUILD/HubDrop-$VERSION.zip"

echo "==> Signed as:"
codesign -dvv "$APP" 2>&1 | grep -E '^(Authority=Developer ID|TeamIdentifier|CodeDirectory)' | sed 's/^/    /'
echo "    Architectures: $(lipo -archs "$APP/Contents/MacOS/HubDrop")"

if (( NOTARIZE )); then
    echo "==> Notarizing with keychain profile \"$PROFILE\""
    SUBMIT_ZIP="$BUILD/HubDrop-submit.zip"
    ditto -c -k --keepParent "$APP" "$SUBMIT_ZIP"
    if ! xcrun notarytool submit "$SUBMIT_ZIP" --keychain-profile "$PROFILE" --wait | tee "$BUILD/notarytool.log"; then
        ID="$(sed -n 's/^ *id: //p' "$BUILD/notarytool.log" | head -n 1)"
        echo "Notarization failed. Details:" >&2
        echo "    xcrun notarytool log $ID --keychain-profile $PROFILE" >&2
        exit 1
    fi
    # notarytool exits 0 even when Apple rejects the submission, so check the status line.
    if ! grep -q "status: Accepted" "$BUILD/notarytool.log"; then
        ID="$(sed -n 's/^ *id: //p' "$BUILD/notarytool.log" | head -n 1)"
        echo "Notarization was not accepted. Details:" >&2
        echo "    xcrun notarytool log $ID --keychain-profile $PROFILE" >&2
        exit 1
    fi
    rm -f "$SUBMIT_ZIP"

    echo "==> Stapling"
    xcrun stapler staple "$APP"
else
    echo "==> Skipping notarization"
fi

echo "==> Packaging"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Verifying"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    /'
if (( NOTARIZE )); then
    spctl --assess --type execute --verbose=2 "$APP" 2>&1 | sed 's/^/    /'
fi

echo
echo "Release ready: $ZIP"
