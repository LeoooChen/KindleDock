#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/packaging/dependencies.env"
VENDOR="$ROOT/.build/vendor"
mkdir -p "$VENDOR"
if [[ -f "$VENDOR/.verified-$MACFUSE_SHA256" && -f "$VENDOR/macFUSE.pkg" ]]; then
  exit 0
fi
DMG="$VENDOR/macfuse-$MACFUSE_VERSION.dmg"
if [[ ! -f "$DMG" ]]; then
  curl --fail --location --retry 3 --connect-timeout 15 --max-time 180 "$MACFUSE_URL" -o "$DMG.download"
  mv "$DMG.download" "$DMG"
fi
ACTUAL="$(shasum -a 256 "$DMG" | awk '{print $1}')"
[[ "$ACTUAL" == "$MACFUSE_SHA256" ]] || { echo 'macFUSE checksum mismatch' >&2; exit 1; }
MOUNT="$VENDOR/macfuse-volume"
mkdir -p "$MOUNT"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$MOUNT" "$DMG"
trap 'hdiutil detach -quiet "$MOUNT" || true' EXIT
cp "$MOUNT/Extras/macFUSE $MACFUSE_VERSION.pkg" "$VENDOR/macFUSE.pkg"
pkgutil --check-signature "$VENDOR/macFUSE.pkg" > "$VENDOR/signature.txt"
grep -q 'Developer ID Installer: Benjamin Fleischer (3T5GSNBU6W)' "$VENDOR/signature.txt"
if [[ -d "$VENDOR/expanded" ]]; then rm -rf "$VENDOR/expanded"; fi
pkgutil --expand "$VENDOR/macFUSE.pkg" "$VENDOR/expanded"
touch "$VENDOR/.verified-$MACFUSE_SHA256"
echo "Verified official macFUSE $MACFUSE_VERSION installer"
