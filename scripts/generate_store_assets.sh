#!/usr/bin/env bash
# Generate Play Store / App Store sized assets from a single source icon
# Usage: ./scripts/generate_store_assets.sh path/to/app_icon.png

set -euo pipefail

SRC=${1:-assets/icons/app_icon.png}
OUT_DIR=store_assets

if [ ! -f "$SRC" ]; then
  echo "Source icon not found: $SRC"
  echo "Place your PNG at $SRC or pass an explicit path"
  exit 1
fi

mkdir -p $OUT_DIR

# Preferred: use ImageMagick 'magick' command (newer versions), fallback to 'convert'
if command -v magick >/dev/null 2>&1; then
  IM_CMD="magick"
elif command -v convert >/dev/null 2>&1; then
  IM_CMD="convert"
else
  echo "ImageMagick 'magick' or 'convert' not found. Install ImageMagick to use this script."
  exit 1
fi

# Generate Android Play Store icon (512x512)
$IM_CMD "$SRC" -resize 512x512 -background transparent -gravity center -extent 512x512 "$OUT_DIR/play_icon_512.png"

# Generate App Store icon (1024x1024)
$IM_CMD "$SRC" -resize 1024x1024 -background transparent -gravity center -extent 1024x1024 "$OUT_DIR/app_store_icon_1024.png"

# Generate feature graphic for Play Store (1024x500)
$IM_CMD "$SRC" -resize 1024x1024 -background white -gravity center -extent 1024x500 "$OUT_DIR/feature_graphic_1024x500.png"

echo "Generated assets in $OUT_DIR"