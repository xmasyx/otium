#!/bin/bash
# Costruisce Otium.app — bundle avviabile con doppio clic, firmato ad-hoc.
# Uso: Scripts/build-app.sh [cartella-destinazione]   (default: ./dist)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$ROOT/dist}"
APP="$DEST/Otium.app"
VERSION="1.0.0"

cd "$ROOT"

echo "▸ compilo (release)…"
swift build -c release --product OtiumApp

echo "▸ icona…"
mkdir -p "$ROOT/.build/icon.iconset"
swift "$ROOT/Scripts/MakeIcon.swift" "$ROOT/.build/icon-1024.png" >/dev/null
for size in 16 32 64 128 256 512; do
    sips -z $size $size "$ROOT/.build/icon-1024.png" \
        --out "$ROOT/.build/icon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$ROOT/.build/icon-1024.png" \
        --out "$ROOT/.build/icon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ROOT/.build/icon.iconset" -o "$ROOT/.build/Otium.icns"

echo "▸ assemblo il bundle…"
mkdir -p "$DEST"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/OtiumApp" "$APP/Contents/MacOS/Otium"
cp "$ROOT/.build/Otium.icns" "$APP/Contents/Resources/Otium.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Otium</string>
    <key>CFBundleDisplayName</key><string>Otium</string>
    <key>CFBundleExecutable</key><string>Otium</string>
    <key>CFBundleIdentifier</key><string>app.otium.mac</string>
    <key>CFBundleIconFile</key><string>Otium</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- Vive nella barra dei menu, non nel Dock. -->
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Locale. Nessuna rete, nessun permesso di sistema.</string>
</dict>
</plist>
PLIST

echo "▸ firma ad-hoc…"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 \
    || echo "  (firma saltata: non blocca l'avvio in locale)"

echo "✓ pronto: $APP"
echo "  apri con:  open \"$APP\""
echo "  registro:  ~/Library/Application Support/Otium/ledger.jsonl"
