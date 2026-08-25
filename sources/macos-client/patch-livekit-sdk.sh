#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_FILE="${ROOT_DIR}/.build/checkouts/client-sdk-swift/Sources/LiveKit/Track/Capturers/MacOSScreenCapturer.swift"

if [[ ! -f "${SDK_FILE}" ]]; then
  echo "LiveKit SDK checkout not found: ${SDK_FILE}" >&2
  exit 1
fi

perl -0pi -e 's/SCShareableContent\.excludingDesktopWindows\(false, onScreenWindowsOnly: true\)/SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)/g' "${SDK_FILE}"

if ! grep -Fq 'SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)' "${SDK_FILE}"; then
  echo "Unable to enable cross-Space screen share source enumeration" >&2
  exit 1
fi

echo "Patched LiveKit to enumerate shareable windows across all macOS Spaces"
