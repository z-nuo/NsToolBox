#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/NsToolBox.app"
mkdir -p "$BUILD_DIR/arm64" "$BUILD_DIR/x86_64"
cd "$ROOT_DIR"

build_arch() {
    local target_arch="$1"
    local triple="$target_arch-apple-macosx13.0"
    swift build -c release --triple "$triple" --product NsToolBox
    local bin_dir
    bin_dir="$(swift build -c release --triple "$triple" --show-bin-path)"
    local binary="$bin_dir/NsToolBox"
    test -f "$binary"
    lipo "$binary" -verify_arch "$target_arch"
    cp "$binary" "$BUILD_DIR/$target_arch/NsToolBox"
}

build_arch arm64
build_arch x86_64
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
lipo -create "$BUILD_DIR/arm64/NsToolBox" "$BUILD_DIR/x86_64/NsToolBox" -output "$APP_DIR/Contents/MacOS/NsToolBox"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_DIR"
lipo "$APP_DIR/Contents/MacOS/NsToolBox" -verify_arch arm64 x86_64
codesign --verify --deep --strict "$APP_DIR"
print "Built $APP_DIR"
lipo -info "$APP_DIR/Contents/MacOS/NsToolBox"
