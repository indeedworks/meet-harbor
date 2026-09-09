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
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${ROOT_DIR}/Info.plist")"
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

# Generate all standard and Retina icon sizes from the approved master artwork.
ICONSET_DIR="$(mktemp -d "${ROOT_DIR}/dist/AppIcon.XXXXXX")/AppIcon.iconset"
trap 'rm -rf "$(dirname "${ICONSET_DIR}")"' EXIT
mkdir -p "${ICONSET_DIR}"
for size in 16 32 128 256 512; do
  sips -z "${size}" "${size}" "${ROOT_DIR}/Resources/AppIcon.png" \
    --out "${ICONSET_DIR}/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "${ROOT_DIR}/Resources/AppIcon.png" \
    --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"

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
  DMG_WORK_DIR="$(mktemp -d "${ROOT_DIR}/dist/Installer.XXXXXX")"
  DMG_MOUNT_DIR="${DMG_WORK_DIR}/mount"
  cleanup_installer() {
    if mount | grep -Fq " on ${DMG_MOUNT_DIR} "; then
      hdiutil detach "${DMG_MOUNT_DIR}" >/dev/null || true
    fi
    rm -rf "${DMG_WORK_DIR}" "$(dirname "${ICONSET_DIR}")"
  }
  trap cleanup_installer EXIT
  mkdir -p "${DMG_WORK_DIR}/stage" "${DMG_MOUNT_DIR}"
  ditto "${APP_DIR}" "${DMG_WORK_DIR}/stage/MeetHarbor.app"
  ln -s /Applications "${DMG_WORK_DIR}/stage/Applications"
  cat > "${DMG_WORK_DIR}/stage/安装说明.txt" <<'TEXT'
安装 MeetHarbor

将 MeetHarbor 图标拖到右侧的 Applications（应用程序）文件夹，即可安装。
安装完成后，请从“应用程序”打开 MeetHarbor，并推出此安装磁盘。
TEXT
  hdiutil create \
    -volname "MeetHarbor ${APP_VERSION}" \
    -srcfolder "${DMG_WORK_DIR}/stage" \
    -ov \
    -format UDRW \
    "${DMG_WORK_DIR}/installer.dmg" >/dev/null
  hdiutil attach "${DMG_WORK_DIR}/installer.dmg" \
    -mountpoint "${DMG_MOUNT_DIR}" -nobrowse >/dev/null
  cp "${ROOT_DIR}/Resources/Installer.DS_Store" "${DMG_MOUNT_DIR}/.DS_Store"
  sync
  hdiutil detach "${DMG_MOUNT_DIR}" >/dev/null
  hdiutil convert "${DMG_WORK_DIR}/installer.dmg" -format UDZO \
    -o "${DMG_WORK_DIR}/final.dmg" >/dev/null
  mv -f "${DMG_WORK_DIR}/final.dmg" "${DMG_PATH}"
  echo "Built DMG: ${DMG_PATH}"
fi
