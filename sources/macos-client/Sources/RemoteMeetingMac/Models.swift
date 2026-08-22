import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: Date
}

struct EmptyResponse: Decodable {}

struct LoginResponse: Decodable {
    let accessToken: String
    let expiresAt: Date
    let account: String
    let nickname: String
    let role: String
}

struct MeetingDetail: Decodable, Identifiable {
    let id: Int
    let topic: String
    let meetingNo: String
    let invitationLink: String
    let status: String
    let hostName: String
    let scheduledStartAt: Date?
    let startedAt: Date?
    let clientSessionId: String?
}

struct JoinMeetingResponse: Decodable {
    let meeting: MeetingDetail
    let liveKit: LiveKitConnection
}

struct LiveKitConnection: Decodable {
    let url: String
    let roomName: String
    let participantToken: String
    let expiresAt: Date
}

struct MeetingHistoryItem: Decodable, Identifiable {
    let id: Int
    let topic: String
    let meetingNo: String
    let status: String
    let scheduledStartAt: Date?
    let startedAt: Date?
    let endedAt: Date?
    let durationSeconds: Int
}

struct ClientRecording: Decodable, Identifiable {
    let id: Int
    let meetingTopic: String
    let meetingNo: String
    let status: String
    let fileName: String?
    let fileSizeBytes: Int64
    let createdAt: Date
    let expiredAt: Date?
}

struct MeetingRuntimeState: Decodable {
    let meetingNo: String
    let participants: [String: ParticipantRuntimeState]
    let screenShare: ScreenShareState?
    let updatedAt: Date
}

struct ParticipantRuntimeState: Decodable {
    let account: String
    let nickname: String
    let muted: Bool
    let networkQuality: String
    let latencyMs: Int?
    let packetLossPercent: Double?
    let audioBitrateKbps: Int?
    let screenShareBitrateKbps: Int?
    let updatedAt: Date
}

struct ScreenShareState: Decodable {
    let active: Bool
    let account: String
    let nickname: String
    let scope: String
    let sourceName: String
    let startedAt: Date
}

struct ScreenShareResponse: Decodable {
    let runtime: MeetingRuntimeState
    let replacedAccount: String?
}

struct SignalingEvent: Identifiable, Decodable {
    let id = UUID()
    let type: String
    let meetingNo: String?
    let account: String?
    let nickname: String?
    let serverTime: Date?

    private enum CodingKeys: String, CodingKey {
        case type
        case meetingNo
        case account
        case nickname
        case serverTime
    }
}
