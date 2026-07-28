#!/bin/bash
# Builds ClipboardMini as a release .app bundle and packages it into a .pkg
# installer that drops the app into /Applications. The resulting file in
# dist/ can be copied to any Mac and installed by double-clicking.
#
# Usage: ./scripts/build-pkg.sh [version]
set -euo pipefail

VERSION="${1:-1.0.0}"
APP_NAME="ClipboardMini"
BUNDLE_ID="com.clipboardmini.app"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
PKG="$DIST/$APP_NAME-$VERSION.pkg"

echo "==> Building release binary"
swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/$APP_NAME"

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP" "$PKG"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>ClipboardMini</string>
</dict>
</plist>
PLIST

echo "==> Code signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> Building installer package"
pkgbuild \
    --component "$APP" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location /Applications \
    "$PKG"

echo ""
echo "Done: $PKG"
echo "Copy this file to another Mac and double-click to install into /Applications."
echo "Note: the package is ad-hoc signed. On first launch Gatekeeper may require"
echo "right-click > Open, or approval in System Settings > Privacy & Security."
