#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
cd "$PROJECT_DIR"

swift build -c release --disable-sandbox
BUILD_DIR="$(swift build --show-bin-path -c release)"
APP_DIR="$BUILD_DIR/Steward.app"
STAGING="/tmp/steward-dmg"

rm -rf "$STAGING"
mkdir -p "$STAGING"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/Steward" "$APP_DIR/Contents/MacOS/Steward"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
[ -f Resources/Steward.icns ] && cp Resources/Steward.icns "$APP_DIR/Contents/Resources/Steward.icns"
# Use stable cert if available (avoids keychain dialog from changing ad-hoc identity)
# Prefer Steward Local Signing cert (created by scripts/setup_signing.sh)
CERT=$(security find-identity 2>/dev/null | grep -E '^ *[0-9]+\)' | grep -i "Steward Local Signing" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
if [ -z "$CERT" ]; then
  # Fallback to Apple Development cert (from Xcode)
  CERT=$(security find-identity 2>/dev/null | grep -E '^ *[0-9]+\)' | grep -i "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
fi
if [ -n "$CERT" ]; then
  echo "Signing with: $CERT"
  codesign --force --deep --sign "$CERT" "$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR"
fi

cp -R "$APP_DIR" "$STAGING/Steward.app"
ln -s /Applications "$STAGING/Applications"

# Use unique temp volume name to avoid conflicts with old mounts
VOL_NAME="Steward-Install"
TMP_DMG="/tmp/steward-tmp.dmg"
rm -f "$TMP_DMG"

hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" \
  -ov -format UDRW -fs HFS+ "$TMP_DMG" >/dev/null

# Attach with unique volume name
hdiutil attach "$TMP_DMG" -readwrite -noverify -mountpoint "/Volumes/$VOL_NAME" >/dev/null

osascript <<EOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 100, 680, 420}
    set arrangement of icon view options of container window to not arranged
    set icon size of icon view options of container window to 96
    set position of item "Steward.app" of container window to {340, 120}
    set position of item "Applications" of container window to {130, 120}
  end tell
  close every window
end tell
EOF

sleep 1
# Retry detach — old dist DMG can block the mount
for _ in 1 2 3; do
  if hdiutil detach "/Volumes/$VOL_NAME" -quiet -force 2>/dev/null; then break; fi
  sleep 1
done
sleep 1

mkdir -p dist
rm -f dist/Steward.dmg
hdiutil convert "$TMP_DMG" -ov -format UDZO -imagekey zlib-level=9 -o dist/Steward.dmg >/dev/null

rm -f "$TMP_DMG"
rm -rf "$STAGING"
echo "✅ dist/Steward.dmg"
