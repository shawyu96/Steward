#!/bin/bash
# Generate Steward.app icons from SVG
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/../Resources"
ICONSET_DIR="/tmp/Steward.iconset"
mkdir -p "$ICONSET_DIR"

# SVG source
SVG="$RESOURCES_DIR/AppIcon.svg"

# Required sizes for macOS (from documentation)
# icon_16x16.png, icon_16x16@2x.png (32)
# icon_32x32.png, icon_32x32@2x.png (64)
# icon_128x128.png, icon_128x128@2x.png (256)
# icon_256x256.png, icon_256x256@2x.png (512)
# icon_512x512.png, icon_512x512@2x.png (1024)

sizes=(
  "16,icon_16x16.png"
  "32,icon_16x16@2x.png"
  "32,icon_32x32.png"
  "64,icon_32x32@2x.png"
  "128,icon_128x128.png"
  "256,icon_128x128@2x.png"
  "256,icon_256x256.png"
  "512,icon_256x256@2x.png"
  "512,icon_512x512.png"
  "1024,icon_512x512@2x.png"
)

echo "Generating icons..."
for entry in "${sizes[@]}"; do
  size="${entry%,*}"
  name="${entry#*,}"
  # Use sips to resize from the 1024px version
  # First generate the 1024 base if we haven't yet
  if [ ! -f "$ICONSET_DIR/icon_512x512@2x.png" ]; then
    echo "  Rendering 1024x1024 base..."
    # Try rsvg-convert if available, otherwise use python3 cairosvg
    if command -v rsvg-convert &>/dev/null; then
      rsvg-convert -w 1024 -h 1024 "$SVG" -o "$ICONSET_DIR/icon_512x512@2x.png"
    elif python3 -c "import cairosvg" 2>/dev/null; then
      python3 -c "
import cairosvg
cairosvg.svg2png(url='$SVG', output_width=1024, output_height=1024, write_to='$ICONSET_DIR/icon_512x512@2x.png')
"
    else
      echo "ERROR: Need rsvg-convert (librsvg) or cairosvg (pip install cairosvg)"
      echo "Install: brew install librsvg"
      echo "Or: pip3 install cairosvg"
      exit 1
    fi
  fi

  # Resize
  if [ "$size" -ne 1024 ]; then
    echo "  Resizing to ${size}x${size} → $name"
    sips -z "$size" "$size" "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/$name" &>/dev/null
  fi
done

echo "Creating .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/Steward.icns"

# Cleanup
rm -rf "$ICONSET_DIR"

echo "✅ $RESOURCES_DIR/Steward.icns"
