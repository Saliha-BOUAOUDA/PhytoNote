#!/usr/bin/env bash
# Builds a .deb package for PhytoNote from the Flutter Linux release bundle.
# Output: build/PhytoNote_<version>_amd64.deb at the project root.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/app"
BUILD_DIR="$PROJECT_ROOT/build"
ICON_SRC="$APP_DIR/assets/icon/icon.png"

cd "$APP_DIR"

# Read version from pubspec.yaml — line "version: 1.0.1+12" → "1.0.1"
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
ARCH="amd64"
PKG="phytonote"
PKG_NAME="${PKG}_${VERSION}_${ARCH}"
PKG_DIR="$BUILD_DIR/$PKG_NAME"

echo "==> Building Linux release bundle"
flutter build linux --release --no-pub >/dev/null

echo "==> Preparing .deb tree at $PKG_DIR"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/lib/phytonote"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/applications"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/512x512/apps"

cp -r "$APP_DIR/build/linux/x64/release/bundle/." "$PKG_DIR/usr/lib/phytonote/"

INSTALLED_KB="$(du -sk "$PKG_DIR/usr" | cut -f1)"

echo "==> Resizing icons"
ICON_SRC="$ICON_SRC" PKG_DIR="$PKG_DIR" python3 - <<'PY'
import os
from PIL import Image
src = os.environ["ICON_SRC"]
pkg = os.environ["PKG_DIR"]
img = Image.open(src).convert("RGBA")
for size in (256, 512):
    out = f"{pkg}/usr/share/icons/hicolor/{size}x{size}/apps/phytonote.png"
    img.resize((size, size), Image.LANCZOS).save(out)
PY

echo "==> Writing control file"
cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: phytonote
Version: $VERSION
Section: science
Priority: optional
Architecture: $ARCH
Depends: libgtk-3-0, libglib2.0-0, libstdc++6
Maintainer: Saliha BOUAOUDA <sl.bouaouda@gmail.com>
Installed-Size: $INSTALLED_KB
Description: PhytoNote — saisie validée pour spectrophotométrie UV
 Application offline-first pour la saisie en temps réel des DOs
 sur un spectrophotomètre UV : DPPH, FRAP, CAT, TPC, TFC, ABTS,
 antibactérien, anti-inflammatoire. Validation immédiate, export
 Excel, calibration et IC50 live.
EOF

echo "==> Writing launcher script"
cat > "$PKG_DIR/usr/bin/phytonote" <<'EOF'
#!/usr/bin/env bash
exec /usr/lib/phytonote/phytonote "$@"
EOF
chmod +x "$PKG_DIR/usr/bin/phytonote"

echo "==> Writing .desktop file"
cat > "$PKG_DIR/usr/share/applications/phytonote.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=PhytoNote
GenericName=Saisie spectrophotométrie UV
Comment=Saisie validée + IC50 live + export Excel — DPPH, FRAP, CAT, TPC, TFC, ABTS, antibac, anti-inflam.
Exec=phytonote
Icon=phytonote
Terminal=false
Categories=Science;Education;
Keywords=lab;spectrophotometry;DPPH;FRAP;antioxidant;
EOF

echo "==> Building .deb package"
dpkg-deb --build --root-owner-group "$PKG_DIR" "$BUILD_DIR/${PKG_NAME}.deb" >/dev/null
echo "✓ Built $BUILD_DIR/${PKG_NAME}.deb ($(du -h "$BUILD_DIR/${PKG_NAME}.deb" | cut -f1))"
