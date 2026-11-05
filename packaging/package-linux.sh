#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/deployment/ClipCut.dist"
OUT="$ROOT/dist"
ICON="$ROOT/assets/branding/clipcut-split-timeline-smooth.svg"

if [[ ! -x "$DIST/main.bin" ]]; then
    echo "Standalone build not found: $DIST/main.bin" >&2
    echo "Run pyside6-deploy first." >&2
    exit 1
fi

mkdir -p "$OUT"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

tar_root="$stage/ClipCut-linux-x86_64"
mkdir -p "$tar_root"
cp -a "$DIST/." "$tar_root/"
rm -rf "$tar_root/.github" "$tar_root/packaging"
ln -s main.bin "$tar_root/ClipCut"
cp "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/packaging/README-BINARY.txt" "$tar_root/"
tar -C "$stage" -czf "$OUT/ClipCut-linux-x86_64.tar.gz" "ClipCut-linux-x86_64"

appdir="$stage/ClipCut.AppDir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" \
         "$appdir/usr/share/icons/hicolor/scalable/apps" "$appdir/usr/share/doc/clipcut"
cp -a "$DIST/." "$appdir/usr/bin/"
rm -rf "$appdir/usr/bin/.github" "$appdir/usr/bin/packaging"
ln -s main.bin "$appdir/usr/bin/ClipCut"
cp "$ROOT/packaging/clipcut.desktop" "$appdir/usr/share/applications/clipcut.desktop"
cp "$ROOT/packaging/clipcut.desktop" "$appdir/clipcut.desktop"
cp "$ICON" "$appdir/usr/share/icons/hicolor/scalable/apps/clipcut.svg"
cp "$ICON" "$appdir/clipcut.svg"
cp "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/packaging/README-BINARY.txt" "$appdir/usr/share/doc/clipcut/"
cat > "$appdir/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/ClipCut" "$@"
APPRUN
chmod +x "$appdir/AppRun"

APPIMAGETOOL="${APPIMAGETOOL:-$(command -v appimagetool || true)}"
if [[ -z "$APPIMAGETOOL" ]]; then
    echo "Created tar.gz. Set APPIMAGETOOL or install appimagetool to create the AppImage." >&2
    exit 0
fi

APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$APPIMAGETOOL" "$appdir" "$OUT/ClipCut-x86_64.AppImage"
