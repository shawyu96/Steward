#!/bin/bash
# Build and package Steward as a .app bundle
set -euo pipefail

BUILD_DIR="$(swift build --show-bin-path)"
APP_NAME="Steward"

if [ "${CONFIGURATION:-debug}" = "release" ]; then
    swift build -c release --disable-sandbox
else
    swift build
fi

APP_DIR="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_DIR"

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/Steward.icns "$APP_DIR/Contents/Resources/Steward.icns" 2>/dev/null || true

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

echo "✅ $APP_DIR"
echo ""
echo "Run: open \"$APP_DIR\""
