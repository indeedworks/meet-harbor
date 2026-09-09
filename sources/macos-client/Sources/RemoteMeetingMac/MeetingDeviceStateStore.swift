import Foundation
import CryptoKit

/// Local device intent only; media credentials and screen capture are never saved.
struct MeetingDeviceStateStore {
    struct Context: Codable, Equatable {
        let server: String
        let account: String
        let meetingID: Int

        init(server: String, account: String, meetingID: Int) {
            self.server = server.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            self.account = account
            self.meetingID = meetingID
        }
    }

    struct State: Codable {
        let isMuted: Bool
    }

    let directory: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MeetHarbor/MeetingDeviceStates", isDirectory: true)) {
        self.directory = directory
    }

    func load(for context: Context) throws -> State? {
        let url = try fileURL(for: context)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
    }

    func save(isMuted: Bool, for context: Context) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Finish an atomic file write on each change, without relying on an app-exit callback.
        try JSONEncoder().encode(State(isMuted: isMuted)).write(to: fileURL(for: context), options: .atomic)
    }

    private func fileURL(for context: Context) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let digest = SHA256.hash(data: try encoder.encode(context)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".json")
    }

    /// The fresh participant token returned by join/reconnect uses the authenticated account as sub.
    /// Decode only for local storage partitioning, never for authorization or persistence of the token.
    static func account(fromParticipantToken token: String) -> String? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = claims["sub"] as? String, !account.isEmpty else { return nil }
        return account
    }
}
