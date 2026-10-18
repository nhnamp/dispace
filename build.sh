#!/bin/zsh
# Builds Dispace.app and installs it in /Applications.
# Usage: ./build.sh            build and install
#        ./build.sh --no-install   build only (output: build/Dispace.app)
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Dispace.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling…"
swiftc -O -target arm64-apple-macos14.0 -sdk "$(xcrun --show-sdk-path)" \
    Sources/*.swift -o "$APP/Contents/MacOS/Dispace" \
    -framework AppKit -framework ServiceManagement

echo "Making the icon…"
swift Icon/make_icon.swift build/AppIcon.iconset > /dev/null
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# A stable signature keeps the Accessibility permission after a rebuild.
# Ad-hoc signing works too, but then macOS asks for the permission again after each build.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
if [[ -n "$IDENTITY" ]]; then
    echo "Signing with: $IDENTITY"
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "No Apple Development identity found. Signing ad-hoc."
    codesign --force --sign - "$APP"
fi

[[ "${1:-}" == "--no-install" ]] && { echo "Built $APP"; exit 0; }

echo "Installing in /Applications…"
if pgrep -x Dispace > /dev/null; then
    osascript -e 'tell application id "com.nhaatjnamphan.Dispace" to quit' 2>/dev/null || true
    sleep 1
fi
rm -rf /Applications/Dispace.app
cp -R "$APP" /Applications/Dispace.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Dispace.app
echo "Installed /Applications/Dispace.app. Open it from Raycast: type \"Dispace\"."
