#!/bin/bash
# Build a self-contained arm64 application. macFUSE remains a system runtime.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source packaging/dependencies.env
BREW="$(brew --prefix)"
MTP="$(brew --prefix libmtp)"
USB="$(brew --prefix libusb)"
VERSION="$(tr -d '\n' < VERSION)"
ACTUAL_MTP="$(sed -nE 's/^#define LIBMTP_VERSION_STRING "([^"]+)".*/\1/p' "$MTP/include/libmtp.h")"
[[ "$(uname -m)" == arm64 ]] || { echo 'Apple Silicon build required' >&2; exit 1; }
[[ "$ACTUAL_MTP" == "$LIBMTP_VERSION" ]] || { echo "Need libmtp $LIBMTP_VERSION, found $ACTUAL_MTP" >&2; exit 1; }
[[ -f /usr/local/include/fuse3/fuse.h && -f /usr/local/lib/libfuse3.4.dylib ]] || {
  echo 'Install official macFUSE 5.5+ headers and runtime first. See docs/BUILDING.md.' >&2; exit 1;
}
make -s BREW="$BREW"
APP="$ROOT/dist/KindleDock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/"{MacOS,Helpers,Frameworks,Resources/Licenses} "$ROOT/.build"
cp app/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos15.4 \
  -framework SwiftUI -framework AppKit -framework IOKit app/*.swift -o "$APP/Contents/MacOS/KindleDock"
cp kindle-mtpfs "$APP/Contents/Helpers/"
cp "$MTP/lib/libmtp.9.dylib" "$USB/lib/libusb-1.0.0.dylib" "$APP/Contents/Frameworks/"
F="$APP/Contents/Frameworks"
H="$APP/Contents/Helpers/kindle-mtpfs"
chmod u+w "$F/"*.dylib
install_name_tool -id @rpath/libusb-1.0.0.dylib "$F/libusb-1.0.0.dylib"
install_name_tool -id @rpath/libmtp.9.dylib "$F/libmtp.9.dylib"
while read -r dep; do
  install_name_tool -change "$dep" @rpath/libusb-1.0.0.dylib "$F/libmtp.9.dylib"
done < <(otool -L "$F/libmtp.9.dylib" | awk 'NR>1 && /libusb-1.0/{print $1}')
install_name_tool -add_rpath @loader_path "$F/libmtp.9.dylib"
while read -r dep; do
  install_name_tool -change "$dep" @rpath/libmtp.9.dylib "$H"
done < <(otool -L "$H" | awk 'NR>1 && /libmtp/{print $1}')
install_name_tool -add_rpath @executable_path/../Frameworks "$H"
if otool -L "$H" "$F/"*.dylib | grep -E '^[[:space:]]+/(opt/homebrew|usr/local/opt|usr/local/Cellar)/'; then
  echo 'A Homebrew runtime dependency escaped bundling' >&2; exit 1
fi
cp LICENSE "$APP/Contents/Resources/Licenses/LICENSE-KindleDock.txt"
cp "$MTP/COPYING" "$APP/Contents/Resources/Licenses/COPYING-libmtp.txt"
cp "$USB/COPYING" "$APP/Contents/Resources/Licenses/COPYING-libusb.txt"
cp app/THIRD-PARTY-NOTICES.txt packaging/MACFUSE-LICENSE.txt "$APP/Contents/Resources/Licenses/"
{
  echo "libmtp $ACTUAL_MTP"
  echo "libusb $(basename "$(readlink "$USB")")"
} > "$APP/Contents/Resources/Licenses/versions.txt"
swift scripts/render-icon.swift "$ROOT/.build/KindleDock.iconset"
iconutil -c icns "$ROOT/.build/KindleDock.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
IDENTITY="${SIGNING_IDENTITY:--}"
SIGN_OPTIONS=()
if [[ "$IDENTITY" != '-' ]]; then SIGN_OPTIONS=(--options runtime --timestamp); fi
codesign --force --sign "$IDENTITY" ${SIGN_OPTIONS[@]+"${SIGN_OPTIONS[@]}"} "$F/libusb-1.0.0.dylib" "$F/libmtp.9.dylib" "$H"
codesign --force --sign "$IDENTITY" ${SIGN_OPTIONS[@]+"${SIGN_OPTIONS[@]}"} "$APP"
codesign --verify --strict --deep "$APP"
for binary in "$APP/Contents/MacOS/KindleDock" "$H" "$F/"*.dylib; do
  lipo -archs "$binary" | grep -qw arm64 || { echo "Missing arm64: $binary" >&2; exit 1; }
done
"$H" --help >/dev/null
echo "Built $APP ($VERSION)"
