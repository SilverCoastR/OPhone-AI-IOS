#!/bin/bash
set -euo pipefail
: "${CERTIFICATE_P12_BASE64:?}"
: "${CERTIFICATE_PASSWORD:?}"
: "${PROVISIONING_PROFILE_BASE64:?}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-ophone-ai-ci}"

CERTIFICATE_PATH="$RUNNER_TEMP/ophone-ai.p12"
PROFILE_PATH="$RUNNER_TEMP/ophone-ai.mobileprovision"
KEYCHAIN_PATH="$RUNNER_TEMP/ophone-ai.keychain-db"
echo -n "$CERTIFICATE_P12_BASE64" | base64 --decode > "$CERTIFICATE_PATH"
echo -n "$PROVISIONING_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE_PATH" -P "$CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
PROFILE_UUID=$(security cms -D -i "$PROFILE_PATH" | /usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin)
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
