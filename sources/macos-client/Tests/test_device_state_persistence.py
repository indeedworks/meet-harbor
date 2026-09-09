"""Compile the real store and check recovery across a killed writer process."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

HARNESS = r'''
import Foundation
@main struct Check {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[2])
        let store = MeetingDeviceStateStore(directory: directory)
        let context = MeetingDeviceStateStore.Context(server: "http://localhost:8080/", account: "alice", meetingID: 1)
        switch CommandLine.arguments[1] {
        case "write":
            try store.save(isMuted: true, for: context)
            print("saved")
            fflush(stdout)
            while true { Thread.sleep(forTimeInterval: 1) }
        case "read":
            precondition(try store.load(for: context)?.isMuted == true)
            let equivalent = MeetingDeviceStateStore.Context(server: "http://localhost:8080", account: "alice", meetingID: 1)
            precondition(try store.load(for: equivalent)?.isMuted == true)
            for other in [MeetingDeviceStateStore.Context(server: "http://localhost:8080", account: "bob", meetingID: 1),
                          .init(server: "http://localhost:8080", account: "alice", meetingID: 2),
                          .init(server: "http://localhost:8081", account: "alice", meetingID: 1)] {
                precondition(try store.load(for: other) == nil)
            }
            try store.save(isMuted: false, for: context)
        case "unmuted":
            precondition(try store.load(for: context)?.isMuted == false)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            precondition(files.count == 1)
            let bytes = try Data(contentsOf: files[0])
            precondition(String(data: bytes, encoding: .utf8) == "{\"isMuted\":false}")
            try Data("broken".utf8).write(to: files[0])
            do {
                _ = try store.load(for: context)
                fatalError("Corrupt saved state must not silently enable microphone")
            } catch is DecodingError {}
            let payload = Data("{\"sub\":\"用户/alice\"}".utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            precondition(MeetingDeviceStateStore.account(fromParticipantToken: "header.\(payload).sig") == "用户/alice")
            for invalid in ["", "a.b.c", "a.e30.c", "a.b"] {
                precondition(MeetingDeviceStateStore.account(fromParticipantToken: invalid) == nil)
            }
        default: fatalError("Unknown mode")
        }
    }
}
'''


class DeviceStatePersistenceTests(unittest.TestCase):
    def test_killed_process_recovery_isolation_and_corruption(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            harness = root / "Check.swift"
            # Swift precondition uses a non-throwing autoclosure.
            harness.write_text(HARNESS.replace("precondition(try ", "precondition(try! "))
            executable = root / "check"
            subprocess.run(["swiftc", "-parse-as-library", str(harness),
                            str(ROOT / "Sources/RemoteMeetingMac/MeetingDeviceStateStore.swift"),
                            "-o", str(executable)], check=True)
            directory = root / "state"
            writer = subprocess.Popen([str(executable), "write", str(directory)],
                                      stdout=subprocess.PIPE, text=True)
            try:
                self.assertEqual(writer.stdout.readline().strip(), "saved")
            finally:
                writer.kill()
                writer.wait()
                writer.stdout.close()
            for mode in ["read", "unmuted"]:
                subprocess.run([str(executable), mode, str(directory)], check=True)


if __name__ == "__main__":
    unittest.main()
