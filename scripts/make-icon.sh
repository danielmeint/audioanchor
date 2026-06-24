#!/usr/bin/env bash
#
# Generate Resources/AppIcon.icns from a rendered 1024px master.
# Run from anywhere: scripts/make-icon.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Rendering 1024px master..."
swift scripts/IconRenderer.swift "$TMP/icon-1024.png"

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

sizes=(
  "icon_16x16.png 16"
  "icon_16x16@2x.png 32"
  "icon_32x32.png 32"
  "icon_32x32@2x.png 64"
  "icon_128x128.png 128"
  "icon_128x128@2x.png 256"
  "icon_256x256.png 256"
  "icon_256x256@2x.png 512"
  "icon_512x512.png 512"
  "icon_512x512@2x.png 1024"
)
echo "==> Resizing iconset..."
for entry in "${sizes[@]}"; do
  name="${entry% *}"
  dim="${entry##* }"
  sips -z "$dim" "$dim" "$TMP/icon-1024.png" --out "$ICONSET/$name" >/dev/null
done

mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "==> Wrote Resources/AppIcon.icns"
