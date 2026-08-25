#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT_DIR}"

swift package resolve
bash "${ROOT_DIR}/patch-livekit-sdk.sh"
swift build
swift build --triple x86_64-apple-macosx14.0

ARM_BIN_DIR="$(swift build --show-bin-path)"
X64_BIN_DIR="$(swift build --triple x86_64-apple-macosx14.0 --show-bin-path)"
APP_NAME="RemoteMeetingMac"
APP_VERSION="0.1.6"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
DMG_PATH="${ROOT_DIR}/dist/${APP_NAME}-${APP_VERSION}-universal.dmg"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

if [[ -z "${SIGN_IDENTITY}" ]]; then
  SIGN_IDENTITY="-"
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}"

lipo -create \
  "${ARM_BIN_DIR}/${APP_NAME}" \
  "${X64_BIN_DIR}/${APP_NAME}" \
  -output "${MACOS_DIR}/${APP_NAME}"
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true

for framework in "${ARM_BIN_DIR}"/*.framework; do
  if [[ -d "${framework}" ]]; then
    cp -R "${framework}" "${FRAMEWORKS_DIR}/"
  fi
done

for bundle in "${ARM_BIN_DIR}"/*.bundle; do
  if [[ -d "${bundle}" ]]; then
    cp -R "${bundle}" "${RESOURCES_DIR}/"
  fi
done

cp "${ROOT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

ENTITLEMENTS_FILE="${ROOT_DIR}/dist/RemoteMeetingMac.entitlements.plist"
cat > "${ENTITLEMENTS_FILE}" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  while IFS= read -r item; do
    codesign --force --sign "${SIGN_IDENTITY}" "${item}"
  done < <(find "${FRAMEWORKS_DIR}" -maxdepth 1 -type d -name "*.framework")
  codesign --force --sign "${SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS_FILE}" "${APP_DIR}"
fi

echo "Built universal app: ${APP_DIR}"
lipo -archs "${MACOS_DIR}/${APP_NAME}"
echo "Code signing identity: ${SIGN_IDENTITY}"

if command -v hdiutil >/dev/null 2>&1; then
  rm -f "${DMG_PATH}"
  hdiutil create \
    -volname "${APP_NAME}-Universal-${APP_VERSION}" \
    -srcfolder "${APP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}" >/dev/null
  echo "Built DMG: ${DMG_PATH}"
fi
