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

# Privacy boundary: finish removing screen tracks before either quick or full
# reconnect can restore the publisher transport. Serialize with pending publishes.
PARTICIPANT_FILE="${ROOT_DIR}/.build/checkouts/client-sdk-swift/Sources/LiveKit/Participant/LocalParticipant.swift"
ENGINE_FILE="${ROOT_DIR}/.build/checkouts/client-sdk-swift/Sources/LiveKit/Core/Room+Engine.swift"
perl -0pi -e 's/    func republishAllTracks\(\) async throws \{/    public func stopScreenShareBeforeReconnect() async throws {
        _ = try await _publishSerialRunner.run {
            let publications = self._state.trackPublications.values.compactMap { \$0 as? LocalTrackPublication }
            for publication in publications where publication.source == .screenShareVideo || publication.source == .screenShareAudio {
                if let track = publication.track as? LocalTrack {
                    try await track.stop()
                }
                try await self.unpublish(publication: publication)
            }
            return nil
        }
    }

    func republishAllTracks() async throws {/ unless /func stopScreenShareBeforeReconnect/' "${PARTICIPANT_FILE}"
perl -0pi -e 's/            if mediaTrack.isMuted \{ continue \}/            if mediaTrack.isMuted || mediaTrack.source == .screenShareVideo || mediaTrack.source == .screenShareAudio { continue }/' "${PARTICIPANT_FILE}"
perl -0pi -e 's/            let reconnectTask = Task.retrying/            try await localParticipant.stopScreenShareBeforeReconnect()

            let reconnectTask = Task.retrying/ unless /try await localParticipant.stopScreenShareBeforeReconnect/' "${ENGINE_FILE}"
if ! grep -Fq 'func stopScreenShareBeforeReconnect() async throws' "${PARTICIPANT_FILE}" ||
   ! grep -Fq 'if mediaTrack.isMuted || mediaTrack.source == .screenShareVideo || mediaTrack.source == .screenShareAudio { continue }' "${PARTICIPANT_FILE}" ||
   ! grep -Fq 'try await localParticipant.stopScreenShareBeforeReconnect()' "${ENGINE_FILE}"; then
  echo "Unable to enforce screen sharing reconnect privacy policy" >&2
  exit 1
fi
echo "Patched LiveKit to stop screen sharing before reconnect and never republish it automatically"
