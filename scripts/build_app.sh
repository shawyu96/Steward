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

# Ad-hoc sign
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "✅ $APP_DIR"
echo ""
echo "Run: open \"$APP_DIR\""
