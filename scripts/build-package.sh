#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source packaging/dependencies.env
VERSION="$(tr -d '\n' < VERSION)"
APP="$ROOT/dist/KindleDock.app"
[[ -d "$APP" ]] || app/build-app.sh
codesign --verify --strict --deep "$APP"
scripts/fetch-macfuse.sh
WORK="$ROOT/.build/package"
rm -rf "$WORK"
mkdir -p "$WORK/root/Applications" "$WORK/components" "$WORK/resources"
ditto "$APP" "$WORK/root/Applications/KindleDock.app"
pkgbuild --analyze --root "$WORK/root" "$WORK/Component.plist"
python3 - "$WORK/Component.plist" <<'PY'
import plistlib,sys
p=sys.argv[1]
with open(p,'rb') as f: items=plistlib.load(f)
for item in items:
    item['BundleIsRelocatable']=False
    item['BundleIsVersionChecked']=True
with open(p,'wb') as f: plistlib.dump(items,f)
PY
pkgbuild --root "$WORK/root" --component-plist "$WORK/Component.plist" \
  --identifier io.github.leooochen.kindledock.app --version "$VERSION" --install-location / \
  --scripts packaging/scripts "$WORK/components/KindleDock-App.pkg"
# Keep the vendor payload/scripts intact. The official DMG SHA and original
# product signature were verified before extracting this component archive.
pkgutil --flatten "$ROOT/.build/vendor/expanded/Core.pkg" "$WORK/components/macFUSE-Core.pkg"
python3 scripts/package-resources.py "$WORK/resources"
sed "s/@VERSION@/$VERSION/g" packaging/Distribution.xml > "$WORK/Distribution.xml"
PKG="$ROOT/dist/KindleDock-$VERSION-arm64.pkg"
SIGN_ARGS=()
if [[ -n "${INSTALLER_SIGNING_IDENTITY:-}" ]]; then SIGN_ARGS=(--sign "$INSTALLER_SIGNING_IDENTITY" --timestamp); fi
productbuild --distribution "$WORK/Distribution.xml" --package-path "$WORK/components" \
  --resources "$WORK/resources" ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} "$PKG"
# Stable names make the README download buttons work across releases.
cp "$PKG" "$ROOT/dist/KindleDock-arm64.pkg"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
cp "$PKG" "$STAGE/Install KindleDock.pkg"
cp docs/INSTALL.txt "$STAGE/Read Me First.txt"
hdiutil create -quiet -volname KindleDock -srcfolder "$STAGE" -ov -format UDZO "$ROOT/dist/KindleDock-$VERSION-arm64.dmg"
ditto -c -k --keepParent "$APP" "$ROOT/dist/KindleDock-$VERSION-arm64.zip"
(cd dist && shasum -a 256 *.pkg *.dmg *.zip > SHA256SUMS.txt)
if [[ -n "${INSTALLER_SIGNING_IDENTITY:-}" ]]; then
  pkgutil --check-signature "$PKG"
else
  echo 'Unsigned installer built; Developer ID signing/notarization was not configured.'
fi
echo "Built installer: $PKG"
