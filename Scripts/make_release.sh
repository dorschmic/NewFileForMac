#!/bin/bash
# Baut eine ZIP zum Weitergeben (GitHub Release) – OHNE Entwicklerzertifikat.
#
# Warum ad hoc ("-") statt "Apple Development"? Entwicklerzertifikate sind
# laut Apple nur für Entwicklung und Tests gedacht, nicht zum Verteilen.
# Ohne Notarisierung (Apple Developer Program, 99 €/Jahr) müssen Nutzer die
# App ohnehin einmal manuell freigeben – daran ändert sich also nichts.
#
# Ergebnis: dist/NewFileForMac-<Version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME=NewFileForMac
BUILD="$PWD/build-release"
DIST="$PWD/dist"

xcodegen generate --quiet
rm -rf "$BUILD"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
    -derivedDataPath "$BUILD" \
    CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
    build -quiet

APP="$BUILD/Build/Products/Release/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

codesign --verify --deep --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -q "Signature=adhoc" || { echo "Nicht ad hoc signiert!"; exit 1; }

# Die Build-Kopie soll macOS nicht als zweite Installation registrieren
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true

mkdir -p "$DIST"
ZIP="$DIST/$APP_NAME-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Fertig: $ZIP"
