"""Run with python3 tests/test_reconnect_privacy.py after swift package resolve."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SDK = ROOT / '.build/checkouts/client-sdk-swift'
FILES = ['Track/Capturers/MacOSScreenCapturer.swift',
         'Participant/LocalParticipant.swift', 'Core/Room+Engine.swift']


class ReconnectPrivacyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copy(ROOT / 'patch-livekit-sdk.sh', self.root)
        self.sdk = self.root / '.build/checkouts/client-sdk-swift/Sources/LiveKit'
        for name in FILES:
            destination = self.sdk / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(subprocess.check_output(
                ['git', 'show', 'HEAD:Sources/LiveKit/' + name], cwd=SDK))

    def patch(self):
        return subprocess.run(['bash', 'patch-livekit-sdk.sh'], cwd=self.root,
                              capture_output=True, text=True)

    def test_patch_is_idempotent_and_runs_before_transport_recovery(self):
        self.assertEqual(self.patch().returncode, 0)
        first = [(self.sdk / name).read_bytes() for name in FILES]
        self.assertEqual(self.patch().returncode, 0)
        self.assertEqual(first, [(self.sdk / name).read_bytes() for name in FILES])
        engine = (self.sdk / FILES[2]).read_text()
        self.assertLess(engine.index('try await localParticipant.stopScreenShareBeforeReconnect()'),
                        engine.index('let reconnectTask = Task.retrying'))
        participant = (self.sdk / FILES[1]).read_text()
        self.assertIn('mediaTrack.source == .screenShareVideo || mediaTrack.source == .screenShareAudio', participant)

    def test_unknown_sdk_layout_fails_closed(self):
        engine = self.sdk / FILES[2]
        engine.write_text(engine.read_text().replace('let reconnectTask = Task.retrying',
                                                   'let changedTask = Task.retrying'))
        result = self.patch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unable to enforce', result.stderr)

    def test_actual_patched_cleanup_preserves_microphone_and_propagates_failure(self):
        self.assertEqual(self.patch().returncode, 0)
        participant = (self.sdk / FILES[1]).read_text()
        helper = participant[participant.index('    public func stopScreenShareBeforeReconnect()'):
                             participant.index('    func republishAllTracks()')]
        harness = r'''
import Foundation
var events: [String] = []
enum Failure: Error { case capture }
enum Source { case microphone, screenShareVideo, screenShareAudio }
class LocalTrack {
    let name: String
    var fails = false
    init(_ name: String) { self.name = name }
    func stop() async throws {
        events.append("stop:" + name)
        if fails { throw Failure.capture }
    }
}
class LocalTrackPublication {
    let source: Source
    let track: AnyObject?
    init(_ source: Source, _ track: LocalTrack) { self.source = source; self.track = track }
}
class State { var trackPublications: [String: AnyObject] = [:] }
class Runner {
    func run(_ body: () async throws -> LocalTrackPublication?) async throws -> LocalTrackPublication? {
        try await body()
    }
}
class Participant {
    let _state = State()
    let _publishSerialRunner = Runner()
    func unpublish(publication: LocalTrackPublication) async throws {
        let track = publication.track as! LocalTrack
        events.append("unpublish:" + track.name)
        _state.trackPublications.removeValue(forKey: track.name)
    }
__HELPER__
}
@main struct Check {
    static func main() async throws {
        let participant = Participant()
        for (name, source) in [("mic", Source.microphone), ("video", .screenShareVideo), ("audio", .screenShareAudio)] {
            participant._state.trackPublications[name] = LocalTrackPublication(source, LocalTrack(name))
        }
        try await participant.stopScreenShareBeforeReconnect()
        precondition(Set(participant._state.trackPublications.keys) == ["mic"])
        precondition(!events.contains("stop:mic"))
        for name in ["video", "audio"] {
            precondition(events.firstIndex(of: "stop:" + name)! < events.firstIndex(of: "unpublish:" + name)!)
        }
        events = []
        try await participant.stopScreenShareBeforeReconnect()
        precondition(events.isEmpty)
        let failing = LocalTrack("failure")
        failing.fails = true
        participant._state.trackPublications["failure"] = LocalTrackPublication(.screenShareVideo, failing)
        do {
            try await participant.stopScreenShareBeforeReconnect()
            fatalError("Reconnect must not continue after capture cleanup fails")
        } catch Failure.capture {}
        precondition(!events.contains("unpublish:failure"))
    }
}
'''.replace('__HELPER__', helper)
        source = self.root / 'Check.swift'
        source.write_text(harness)
        executable = self.root / 'check'
        subprocess.run(['swiftc', '-parse-as-library', str(source), '-o', str(executable)], check=True)
        subprocess.run([str(executable)], check=True)


if __name__ == '__main__':
    unittest.main()
