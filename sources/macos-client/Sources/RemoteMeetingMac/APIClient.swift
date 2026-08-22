import Foundation

enum APIError: LocalizedError {
    case invalidBaseURL
    case unauthorized
    case serverMessage(String)
    case missingData
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "后端地址不正确"
        case .unauthorized:
            "登录已失效，请重新登录"
        case .serverMessage(let message):
            message
        case .missingData:
            "服务端响应缺少数据"
        case .invalidResponse:
            "服务端响应格式不正确"
        }
    }
}

@MainActor
final class APIClient {
    var baseURLString: String
    var accessToken: String?

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder

    init(baseURLString: String = "http://localhost:8080", accessToken: String? = nil, session: URLSession = .shared) {
        self.baseURLString = baseURLString
        self.accessToken = accessToken
        self.session = session
        self.decoder = JSONDecoder.remoteMeetingDecoder
    }

    func login(account: String, password: String) async throws -> LoginResponse {
        try await request(
            path: "/api/auth/login",
            method: "POST",
            body: ["account": account, "password": password],
            requiresAuth: false
        )
    }

    func changePassword(oldPassword: String, newPassword: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/api/auth/change-password",
            method: "POST",
            body: ["oldPassword": oldPassword, "newPassword": newPassword]
        )
    }

    func createInstantMeeting(topic: String) async throws -> MeetingDetail {
        try await request(
            path: "/api/client/meetings/instant",
            method: "POST",
            body: ["topic": topic]
        )
    }

    func createScheduledMeeting(topic: String, scheduledStartAt: Date) async throws -> MeetingDetail {
        try await request(
            path: "/api/client/meetings/scheduled",
            method: "POST",
            body: ScheduledMeetingBody(
                topic: topic,
                scheduledStartAt: ISO8601DateFormatter().string(from: scheduledStartAt)
            )
        )
    }

    func joinMeeting(meetingNo: String) async throws -> JoinMeetingResponse {
        try await request(
            path: "/api/client/meetings/join",
            method: "POST",
            body: ["meetingNo": meetingNo]
        )
    }

    func reconnectMeeting(clientSessionId: String) async throws -> JoinMeetingResponse {
        try await request(
            path: "/api/client/meetings/reconnect",
            method: "POST",
            body: ["clientSessionId": clientSessionId]
        )
    }

    func leaveMeeting(clientSessionId: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/api/client/meetings/leave",
            method: "POST",
            body: ["clientSessionId": clientSessionId]
        )
    }

    func meetingHistory() async throws -> [MeetingHistoryItem] {
        try await request(path: "/api/client/meetings/history")
    }

    func runtime(meetingNo: String) async throws -> MeetingRuntimeState {
        try await request(path: "/api/client/meetings/\(meetingNo)/runtime")
    }

    func updateMute(meetingNo: String, muted: Bool) async throws -> MeetingRuntimeState {
        try await request(
            path: "/api/client/meetings/\(meetingNo)/mute",
            method: "POST",
            body: ["muted": muted]
        )
    }

    func reportNetworkQuality(
        meetingNo: String,
        quality: String,
        latencyMs: Int?,
        packetLossPercent: Double?,
        audioBitrateKbps: Int?,
        screenShareBitrateKbps: Int?
    ) async throws -> MeetingRuntimeState {
        let body = NetworkQualityBody(
            quality: quality,
            latencyMs: latencyMs,
            packetLossPercent: packetLossPercent,
            audioBitrateKbps: audioBitrateKbps,
            screenShareBitrateKbps: screenShareBitrateKbps
        )
        return try await request(
            path: "/api/client/meetings/\(meetingNo)/network-quality",
            method: "POST",
            body: body
        )
    }

    func startScreenShare(meetingNo: String, scope: String, sourceName: String) async throws -> ScreenShareResponse {
        try await request(
            path: "/api/client/meetings/\(meetingNo)/screen-share/start",
            method: "POST",
            body: ["scope": scope, "sourceName": sourceName]
        )
    }

    func stopScreenShare(meetingNo: String) async throws -> MeetingRuntimeState {
        try await request(
            path: "/api/client/meetings/\(meetingNo)/screen-share/stop",
            method: "POST",
            body: Optional<String>.none
        )
    }

    func recordings() async throws -> [ClientRecording] {
        try await request(path: "/api/client/recordings")
    }

    private func request<T: Decodable, B: Encodable>(
        path: String,
        method: String = "GET",
        body: B? = Optional<String>.none,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let baseURL = URL(string: baseURLString) else {
            throw APIError.invalidBaseURL
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth {
            guard let accessToken else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.unauthorized
        }

        let envelope = try decoder.decode(APIResponse<T>.self, from: data)
        guard envelope.code == 0 else {
            throw APIError.serverMessage(envelope.message)
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        guard let payload = envelope.data else {
            throw APIError.missingData
        }
        return payload
    }

    private struct NetworkQualityBody: Encodable {
        let quality: String
        let latencyMs: Int?
        let packetLossPercent: Double?
        let audioBitrateKbps: Int?
        let screenShareBitrateKbps: Int?
    }

    private struct ScheduledMeetingBody: Encodable {
        let topic: String
        let scheduledStartAt: String
    }
}

private extension JSONDecoder {
    static var remoteMeetingDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = DateParser.parse(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }
}

enum DateParser {
    static func parse(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
