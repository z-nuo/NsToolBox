#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT_DIR/build/app-icon/AppIcon.iconset"
SOURCE="$ROOT_DIR/Resources/AppIcon.svg"
MASTER="$ROOT_DIR/Resources/AppIcon.png"

if ! command -v rsvg-convert >/dev/null 2>&1; then
    print -u2 "Regenerating the vector artwork requires rsvg-convert (librsvg). Normal app builds use the committed AppIcon.icns."
    exit 127
fi
mkdir -p "$ICONSET"
rsvg-convert -w 1024 -h 1024 "$SOURCE" -o "$MASTER"
rsvg-convert -w 512 -h 512 "$SOURCE" -o "$ROOT_DIR/Resources/AppIcon-preview.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$MASTER" --out "$ICONSET/icon_$size"x"$size.png" >/dev/null
    pixels=$((size * 2))
    sips -z "$pixels" "$pixels" "$MASTER" --out "$ICONSET/icon_$size"x"$size@2x.png" >/dev/null
done
iconutil --convert icns "$ICONSET" --output "$ROOT_DIR/Resources/AppIcon.icns"
print "Generated Resources/AppIcon.png, AppIcon-preview.png and AppIcon.icns"
