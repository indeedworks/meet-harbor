import Foundation
import LiveKit
import OSLog

@MainActor
final class LiveKitAdapter: NSObject, ObservableObject, RoomDelegate {
    final class ScreenShareSourceChoice: Identifiable {
        let id: String
        let name: String
        let scope: String
        fileprivate let source: MacOSScreenCaptureSource

        fileprivate init(id: String, name: String, scope: String, source: MacOSScreenCaptureSource) {
            self.id = id
            self.name = name
            self.scope = scope
            self.source = source
        }
    }

    enum ConnectionState: String {
        case disconnected = "未连接"
        case connecting = "连接中"
        case connected = "已连接"
    }

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var roomName: String?
    @Published private(set) var lastError: String?
    @Published private(set) var remoteScreenShareTrack: VideoTrack?
    @Published private(set) var remoteScreenShareOwner: String?
    @Published private(set) var participantNames: [String: String] = [:]

    private var room: Room?
    private var remoteScreenSharePollingTask: Task<Void, Never>?
    private var remoteScreenSharePublicationSid: Track.Sid?
    private var highQualityScreenShareSids: Set<Track.Sid> = []
    private var isStoppingLocalScreenShare = false
    private let logger = Logger(subsystem: "com.zthz.RemoteMeetingMac", category: "LiveKit")

    override init() {
        super.init()
    }

    func connect(using connection: LiveKitConnection, microphoneEnabled: Bool) async throws {
        disconnect()
        state = .connecting
        roomName = connection.roomName
        lastError = nil

        do {
            let room = Room(
                delegate: self,
                roomOptions: RoomOptions(
                    defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                        dimensions: .h1080_169,
                        fps: 30,
                        showCursor: true
                    ),
                    defaultVideoPublishOptions: VideoPublishOptions(
                        screenShareEncoding: VideoEncoding(maxBitrate: 5_000_000, maxFps: 30),
                        simulcast: false,
                        screenShareSimulcastLayers: [],
                        degradationPreference: .balanced
                    ),
                    dynacast: false,
                    stopLocalTrackOnUnpublish: true,
                    reportRemoteTrackStatistics: true
                )
            )
            self.room = room
            try await room.connect(
                url: connection.url,
                token: connection.participantToken,
                connectOptions: ConnectOptions(
                    autoSubscribe: true,
                    reconnectAttempts: 10,
                    enableMicrophone: microphoneEnabled
                )
            )
            guard room.connectionState == .connected else {
                throw LiveKitAdapterError.connectionLost
            }
            state = .connected
            updateParticipantNames(from: room)
            startRemoteScreenSharePolling()
            await refreshRemoteScreenShareRepeatedly()
        } catch {
            state = .disconnected
            room = nil
            let connectionError = LiveKitAdapterError.connectionFailed
            lastError = connectionError.localizedDescription
            logger.error("LiveKit connection failed: \(error.localizedDescription, privacy: .public)")
            throw connectionError
        }
    }

    func disconnect() {
        remoteScreenSharePollingTask?.cancel()
        remoteScreenSharePollingTask = nil
        let room = room
        self.room = nil
        Task {
            await room?.disconnect()
        }
        state = .disconnected
        roomName = nil
        remoteScreenShareTrack = nil
        remoteScreenShareOwner = nil
        remoteScreenSharePublicationSid = nil
        participantNames = [:]
        highQualityScreenShareSids.removeAll()
    }

    func setMicrophoneMuted(_ muted: Bool) async throws {
        let room = try connectedRoom()
        try await room.localParticipant.setMicrophone(enabled: !muted)
    }

    func screenShareSources() async throws -> [ScreenShareSourceChoice] {
        let sources = try await MacOSScreenCapturer.sources(for: .any)
        var displayIndex = 0
        return sources.compactMap { source in
            if let display = source as? MacOSDisplay {
                displayIndex += 1
                return ScreenShareSourceChoice(
                    id: "display-\(display.displayID)",
                    name: "显示器 \(displayIndex)（\(display.width) × \(display.height)）",
                    scope: "SCREEN",
                    source: display
                )
            }
            if let window = source as? MacOSWindow {
                let applicationName = window.owningApplication?.applicationName ?? "应用窗口"
                let windowTitle = window.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = windowTitle?.isEmpty == false ? "\(applicationName) — \(windowTitle!)" : applicationName
                return ScreenShareSourceChoice(
                    id: "window-\(window.windowID)",
                    name: name,
                    scope: "WINDOW",
                    source: window
                )
            }
            return nil
        }
    }

    func startScreenShare(source choice: ScreenShareSourceChoice) async throws {
        let room = try connectedRoom()
        guard !isStoppingLocalScreenShare else {
            throw LiveKitAdapterError.screenShareTransitionInProgress
        }
        let track = LocalVideoTrack.createMacOSScreenShareTrack(
            source: choice.source,
            options: ScreenShareCaptureOptions(dimensions: .h1080_169, fps: 30, showCursor: true),
            reportStatistics: true
        )
        try await room.localParticipant.publish(
            videoTrack: track,
            options: VideoPublishOptions(
                screenShareEncoding: VideoEncoding(maxBitrate: 5_000_000, maxFps: 30),
                simulcast: false,
                screenShareSimulcastLayers: [],
                degradationPreference: .balanced
            )
        )
    }

    func stopScreenShare() async throws {
        guard let room else {
            return
        }
        guard room.connectionState == .connected else {
            return
        }
        guard !isStoppingLocalScreenShare else {
            return
        }
        guard room.localParticipant.firstScreenSharePublication != nil else {
            return
        }
        isStoppingLocalScreenShare = true
        defer { isStoppingLocalScreenShare = false }
        try await room.localParticipant.setScreenShare(enabled: false)
    }

    func refreshRemoteScreenShare() async {
        guard let room else {
            remoteScreenShareTrack = nil
            remoteScreenShareOwner = nil
            remoteScreenSharePublicationSid = nil
            return
        }
        updateRemoteScreenShare(from: room)
    }

    func refreshRemoteScreenShareRepeatedly() async {
        let delays: [UInt64] = [
            0,
            100_000_000,
            250_000_000,
            500_000_000,
            1_000_000_000
        ]
        for delay in delays {
            if Task.isCancelled {
                return
            }
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            await refreshRemoteScreenShare()
            if remoteScreenShareTrack != nil {
                return
            }
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        guard publication.source == .screenShareVideo else {
            return
        }
        Task { @MainActor in
            self.logger.info("Remote screen share published by \(participantDisplayName(participant), privacy: .public)")
            await self.preferHighQuality(for: publication)
            self.updateRemoteScreenShare(from: room, preferredParticipant: participant)
            if self.remoteScreenShareTrack == nil {
                await self.refreshRemoteScreenShareRepeatedly()
            }
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        guard publication.source == .screenShareVideo, publication.track is VideoTrack else {
            return
        }
        Task { @MainActor in
            self.logger.info("Remote screen share subscribed from \(participantDisplayName(participant), privacy: .public)")
            await self.preferHighQuality(for: publication)
            self.updateRemoteScreenShare(from: room, preferredParticipant: participant)
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        guard publication.source == .screenShareVideo else {
            return
        }
        Task { @MainActor in
            self.removeRemoteScreenShare(publication, from: participant, in: room)
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        guard publication.source == .screenShareVideo else {
            return
        }
        Task { @MainActor in
            self.removeRemoteScreenShare(publication, from: participant, in: room)
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        guard trackPublication.source == .screenShareVideo else {
            return
        }
        Task { @MainActor in
            await self.refreshRemoteScreenShareRepeatedly()
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            self.updateParticipantNames(from: room)
            if self.remoteScreenShareOwner == participantDisplayName(participant) {
                self.updateRemoteScreenShare(from: room)
            }
        }
    }

    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            self.updateParticipantNames(from: room)
        }
    }

    nonisolated func room(_ room: Room, participant: Participant, didUpdateName name: String) {
        Task { @MainActor in
            self.updateParticipantNames(from: room)
        }
    }

    nonisolated func room(
        _ room: Room,
        didUpdateConnectionState connectionState: LiveKit.ConnectionState,
        from oldConnectionState: LiveKit.ConnectionState
    ) {
        Task { @MainActor in
            switch connectionState {
            case .connected:
                self.state = .connected
                self.lastError = nil
                self.updateParticipantNames(from: room)
            case .connecting, .reconnecting:
                self.state = .connecting
            case .disconnected, .disconnecting:
                self.state = .disconnected
                self.remoteScreenShareTrack = nil
                self.remoteScreenShareOwner = nil
                self.remoteScreenSharePublicationSid = nil
                self.participantNames = [:]
            @unknown default:
                self.state = .disconnected
            }
        }
    }

    nonisolated func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor in
            self.state = .disconnected
            self.lastError = error == nil ? nil : LiveKitAdapterError.connectionLost.localizedDescription
        }
    }

    private func updateRemoteScreenShare(from room: Room, preferredParticipant: RemoteParticipant? = nil) {
        if let participant = preferredParticipant,
           let screenShare = screenShareVideoTrack(for: participant) {
            remoteScreenShareTrack = screenShare.track
            remoteScreenShareOwner = participantDisplayName(participant)
            remoteScreenSharePublicationSid = screenShare.sid
            requestHighQualityIfNeeded(for: screenShare.publication)
            return
        }

        for participant in room.remoteParticipants.values {
            if let screenShare = screenShareVideoTrack(for: participant) {
                remoteScreenShareTrack = screenShare.track
                remoteScreenShareOwner = participantDisplayName(participant)
                remoteScreenSharePublicationSid = screenShare.sid
                requestHighQualityIfNeeded(for: screenShare.publication)
                return
            }
        }

        remoteScreenShareTrack = nil
        remoteScreenShareOwner = nil
        remoteScreenSharePublicationSid = nil
    }

    private func updateParticipantNames(from room: Room) {
        var names: [String: String] = [:]
        if let identity = room.localParticipant.identity?.stringValue {
            names[identity] = room.localParticipant.name ?? identity
        }
        for participant in room.remoteParticipants.values {
            guard let identity = participant.identity?.stringValue else { continue }
            names[identity] = participant.name ?? identity
        }
        participantNames = names
    }

    private func screenShareVideoTrack(
        for participant: RemoteParticipant
    ) -> (track: VideoTrack, sid: Track.Sid, publication: RemoteTrackPublication)? {
        for publication in participant.videoTracks where publication.source == .screenShareVideo {
            guard !publication.isMuted else {
                continue
            }
            if let track = publication.track as? VideoTrack,
               let remotePublication = publication as? RemoteTrackPublication {
                return (track, publication.sid, remotePublication)
            }
        }
        return nil
    }

    private func removeRemoteScreenShare(
        _ publication: RemoteTrackPublication,
        from participant: RemoteParticipant,
        in room: Room
    ) {
        logger.info("Remote screen share removed from \(participantDisplayName(participant), privacy: .public)")
        if remoteScreenSharePublicationSid == publication.sid {
            remoteScreenShareTrack = nil
            remoteScreenShareOwner = nil
            remoteScreenSharePublicationSid = nil
        }
        highQualityScreenShareSids.remove(publication.sid)
        updateRemoteScreenShare(from: room)
    }

    private func requestHighQualityIfNeeded(for publication: RemoteTrackPublication) {
        guard highQualityScreenShareSids.insert(publication.sid).inserted else {
            return
        }
        Task { @MainActor in
            await preferHighQuality(for: publication)
        }
    }

    private func preferHighQuality(for publication: RemoteTrackPublication) async {
        do {
            try await publication.set(videoQuality: .high)
        } catch {
            highQualityScreenShareSids.remove(publication.sid)
            logger.warning("Failed to request high-quality screen share: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startRemoteScreenSharePolling() {
        remoteScreenSharePollingTask?.cancel()
        remoteScreenSharePollingTask = Task { @MainActor in
            while !Task.isCancelled {
                await refreshRemoteScreenShare()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func connectedRoom() throws -> Room {
        guard let room, room.connectionState == .connected else {
            throw LiveKitAdapterError.notConnected
        }
        return room
    }
}

private func participantDisplayName(_ participant: RemoteParticipant) -> String {
    participant.name ?? participant.identity?.stringValue ?? "对方"
}

enum LiveKitAdapterError: LocalizedError {
    case notConnected
    case connectionFailed
    case connectionLost
    case screenShareTransitionInProgress

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "媒体服务尚未连接，请稍后重试或重新加入会议"
        case .connectionFailed:
            "无法连接媒体服务，请确认服务端地址和网络后重新加入会议"
        case .connectionLost:
            "媒体连接已断开，请重新加入会议"
        case .screenShareTransitionInProgress:
            "屏幕共享正在切换，请稍后再试"
        }
    }

}
