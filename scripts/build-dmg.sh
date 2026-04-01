#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Error: script failed at line $LINENO" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
PROJECT="sprout-pomodoro.xcodeproj"
EXPORT_OPTIONS="$ROOT/ExportOptions.plist"
VERSION=$(grep -m1 'MARKETING_VERSION' "$ROOT/$PROJECT/project.pbxproj" | awk -F' = ' '{gsub(/[; ]/, "", $2); print $2}')
ARCHIVE="$ROOT/build/sprout-pomodoro.xcarchive"
EXPORT_DIR="$ROOT/build/export"
DMG="$ROOT/build/sprout-pomodoro-${VERSION}.dmg"

if [ ! -f "$EXPORT_OPTIONS" ]; then
    echo "Error: ExportOptions.plist not found."
    echo "Copy ExportOptions.plist.template to ExportOptions.plist and fill in your Team ID."
    exit 1
fi

echo "==> Cleaning previous archive..."
[ -d "$ROOT/build" ] && rm -rf "$ARCHIVE" "$EXPORT_DIR"

TEAM_ID=$(plutil -extract teamID raw "$EXPORT_OPTIONS")
if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" = "YOUR_TEAM_ID" ]; then
    echo "Error: teamID in ExportOptions.plist is missing or not set."
    exit 1
fi

SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep "$TEAM_ID" | awk -F'"' '{print $2}' | head -1 || true)
if [ -z "$SIGNING_IDENTITY" ]; then
    echo "Error: Could not find a Developer ID Application certificate for team $TEAM_ID in keychain."
    exit 1
fi

echo "==> Archiving (team: $TEAM_ID)..."
xcodebuild archive \
    -scheme sprout-pomodoro \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    SKIP_INSTALL=NO \
    INSTALL_PATH=/Applications

echo "==> Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR"

echo "==> Staging DMG contents..."
STAGING="$ROOT/build/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$EXPORT_DIR/sprout-pomodoro.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating DMG..."
hdiutil create \
    -volname "Sprout Pomodoro" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG"

echo "==> Signing DMG..."
codesign --force --timestamp -s "$SIGNING_IDENTITY" "$DMG"

echo "==> Submitting DMG to Apple Notary Service (this may take a few minutes)..."
xcrun notarytool submit "$DMG" \
    --keychain-profile "sprout-pomodoro" \
    --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG"

echo "==> Verifying..."
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

echo ""
echo "Done: $DMG"
