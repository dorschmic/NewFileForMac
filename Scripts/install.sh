#!/bin/bash
# Baut die App (Release), installiert sie nach ~/Applications,
# registriert die Finder-Erweiterung und startet die App.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME=NewFileForMac
EXT_ID=de.micheldorsch.NewFileForMac.FinderExtension
DEST="$HOME/Applications/$APP_NAME.app"
BUILD="$PWD/build"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

xcodegen generate --quiet
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
    -derivedDataPath "$BUILD" build -quiet

BUILT="$BUILD/Build/Products/Release/$APP_NAME.app"

# Alte Instanz beenden und ersetzen
pkill -x "$APP_NAME" 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$BUILT" "$DEST"

# Nur die installierte Kopie soll für URL-Schema und Extension zählen
"$LSREGISTER" -u "$BUILT" 2>/dev/null || true
rm -rf "$BUILT"
"$LSREGISTER" -f "$DEST"
pluginkit -a "$DEST/Contents/PlugIns/FinderExtension.appex"
pluginkit -e use -i "$EXT_ID"

open "$DEST"
# Finder neu starten, damit er die (neue) Extension lädt
killall Finder || true

echo "Installiert: $DEST"
pluginkit -m -v -i "$EXT_ID"
