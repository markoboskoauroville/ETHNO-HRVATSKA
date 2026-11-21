#!/bin/sh
# build.sh: Ethno Song Sheets (Mantra).app. Run only by GitHub Actions (.github/workflows/build.yml), never on the Mac.
# The version is `let VERSION = N` in app/App.swift (whole numbers). SIGN=- on the runner; the Mac re-signs "Mantra Apps".
set -e
cd "$(dirname "$0")"
mkdir -p build
V=$(sed -n 's/^let VERSION = \([0-9]*\)/\1/p' app/App.swift)
APP="build/Ethno Song Sheets (Mantra).app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/fonts" "$APP/Contents/Resources/seed"
swiftc -O -swift-version 5 -target arm64-apple-macos14.0 -o "$APP/Contents/MacOS/EthnoSongSheets" app/*.swift
cp fonts/*.ttf "$APP/Contents/Resources/fonts/"
cp songs/[0-9]*.json "$APP/Contents/Resources/seed/"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Ethno Song Sheets (Mantra)</string>
<key>CFBundleDisplayName</key><string>Ethno Song Sheets (Mantra)</string>
<key>CFBundleIdentifier</key><string>community.auroville.ethnosongsheets</string>
<key>CFBundleExecutable</key><string>EthnoSongSheets</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$V</string>
<key>CFBundleVersion</key><string>$V</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSDesktopFolderUsageDescription</key><string>The song library folder.</string>
<key>NSDocumentsFolderUsageDescription</key><string>The song library lives in Documents/ETHNO-HRVATSKA.</string>
</dict></plist>
PL
codesign --force -s "${SIGN:-Mantra Apps}" "$APP"
echo "built $APP (v$V)"
