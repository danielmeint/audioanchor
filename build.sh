#!/usr/bin/env bash
#
# Build AudioAnchor and assemble a runnable .app bundle in ./dist
#
#   ./build.sh                 build (native arch), ad-hoc sign
#   ./build.sh --universal     build a universal (arm64 + x86_64) binary
#   ./build.sh --run           build, then launch the app
#
# For a notarized release set SIGN_ID to your "Developer ID Application" identity:
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./build.sh --universal
#
set -euo pipefail

NAME="AudioAnchor"
BUNDLE_ID="com.danielmeint.audioanchor"
VERSION="${VERSION:-0.1.0}"
CONFIG="release"
SIGN_ID="${SIGN_ID:--}"   # "-" means ad-hoc

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

UNIVERSAL=false
OPEN=false
for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=true ;;
    --run|--open) OPEN=true ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

ARCH_FLAGS=()
LABEL="$CONFIG"
if $UNIVERSAL; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
  LABEL="$CONFIG, universal"
fi

echo "==> Building $NAME ($LABEL)..."
# ${arr[@]+...} guards empty-array expansion, which trips `set -u` on bash 3.2 (macOS default).
swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="dist/$NAME.app"
echo "==> Assembling ${APP}..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$NAME" "$APP/Contents/MacOS/$NAME"

# Copy any SwiftPM-generated resource bundles, if present.
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob

# App icon (generate with scripts/make-icon.sh).
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

echo "==> Codesigning (identity: $SIGN_ID)..."
if [ "$SIGN_ID" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
fi

echo "==> Done: $APP"
$OPEN && { echo "==> Launching..."; open "$APP"; }
