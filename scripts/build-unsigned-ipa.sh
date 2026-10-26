#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rm -rf build/OPhoneAI.xcarchive build/Payload build/OPhone-AI-iOS-unsigned.ipa
xcodebuild \
  -project OPhoneAI.xcodeproj \
  -scheme OPhoneAI \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath build/OPhoneAI.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive
mkdir -p build/Payload
cp -R build/OPhoneAI.xcarchive/Products/Applications/OPhoneAI.app build/Payload/
(cd build && ditto -c -k --sequesterRsrc --keepParent Payload OPhone-AI-iOS-unsigned.ipa)
python3 scripts/validate-ipa.py "$ROOT/build/OPhone-AI-iOS-unsigned.ipa"
echo "Created $ROOT/build/OPhone-AI-iOS-unsigned.ipa"
