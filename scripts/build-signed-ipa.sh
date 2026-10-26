#!/bin/bash
set -euo pipefail
: "${DEVELOPMENT_TEAM:?}"
EXPORT_METHOD="${EXPORT_METHOD:-development}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcodegen generate
rm -rf build/OPhoneAI.xcarchive build/export
xcodebuild -project OPhoneAI.xcodeproj -scheme OPhoneAI -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/OPhoneAI.xcarchive \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates archive
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>$EXPORT_METHOD</string>
  <key>teamID</key><string>$DEVELOPMENT_TEAM</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath build/OPhoneAI.xcarchive \
  -exportPath build/export -exportOptionsPlist build/ExportOptions.plist \
  -allowProvisioningUpdates
