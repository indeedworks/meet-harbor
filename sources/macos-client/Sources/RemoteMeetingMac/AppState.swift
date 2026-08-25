import Foundation
import Combine
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published var baseURLString: String {
        didSet {
            UserDefaults.standard.set(baseURLString, forKey: "baseURLString")
            apiClient.baseURLString = baseURLString
        }
    }
    @Published private(set) var currentUser: LoginResponse?
    @Published private(set) var currentMeeting: MeetingDetail?
    @Published private(set) var lastCreatedMeeting: MeetingDetail?
    @Published private(set) var runtime: MeetingRuntimeState?
    @Published private(set) var history: [MeetingHistoryItem] = []
    @Published private(set) var recordings: [ClientRecording] = []
    @Published private(set) var meetingParticipants: [ParticipantRuntimeState] = []
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var isMuted = false
    @Published var isScreenSharing = false
    @Published private(set) var screenShareSources: [LiveKitAdapter.ScreenShareSourceChoice] = []

    let signalingClient = SignalingClient()
    let liveKitAdapter = LiveKitAdapter()

    private let apiClient: APIClient
    private var cancellables = Set<AnyCancellable>()

    init() {
        let baseURL = UserDefaults.standard.string(forKey: "baseURLString") ?? "http://localhost:8080"
        self.baseURLString = baseURL
        self.apiClient = APIClient(baseURLString: baseURL, accessToken: KeychainStore.loadAccessToken())
        signalingClient.$events
            .compactMap(\.first)
            .sink { [weak self] event in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleSignalingEvent(event)
                }
            }
            .store(in: &cancellables)
        $runtime
            .combineLatest(liveKitAdapter.$participantNames, liveKitAdapter.$state)
            .sink { [weak self] runtime, participantNames, liveKitState in
                self?.rebuildMeetingParticipants(
                    runtime: runtime,
                    participantNames: participantNames,
                    liveKitState: liveKitState
                )
            }
            .store(in: &cancellables)
    }

    var isLoggedIn: Bool {
        currentUser != nil || apiClient.accessToken != nil
    }

    func login(account: String, password: String) async {
        await runBusy {
            let response = try await apiClient.login(account: account, password: password)
            apiClient.accessToken = response.accessToken
            KeychainStore.saveAccessToken(response.accessToken)
            currentUser = response
            await refreshLists()
        }
    }

    func logout() {
        KeychainStore.deleteAccessToken()
        apiClient.accessToken = nil
        currentUser = nil
        currentMeeting = nil
        lastCreatedMeeting = nil
        runtime = nil
        history = []
        recordings = []
        signalingClient.disconnect()
        liveKitAdapter.disconnect()
    }

    func createInstantMeeting(topic: String) async {
        await runBusy {
            let meeting = try await apiClient.createInstantMeeting(topic: topic)
            currentMeeting = meeting
            await refreshLists()
        }
    }

    func startInstantMeeting(topic: String) async {
        await runBusy {
            let meeting = try await apiClient.createInstantMeeting(topic: topic)
            let response = try await apiClient.joinMeeting(meetingNo: meeting.meetingNo)
            try await enterMeeting(response)
            await refreshLists()
        }
    }

    func createScheduledMeeting(topic: String, scheduledStartAt: Date) async {
        lastCreatedMeeting = nil
        await runBusy {
            lastCreatedMeeting = try await apiClient.createScheduledMeeting(
                topic: topic,
                scheduledStartAt: scheduledStartAt
            )
            await refreshLists()
        }
    }

    func joinMeeting(meetingNo: String) async {
        await runBusy {
            let response = try await apiClient.joinMeeting(meetingNo: meetingNo)
            try await enterMeeting(response)
        }
    }

    func reconnectCurrentMeeting() async {
        guard let clientSessionId = currentMeeting?.clientSessionId else {
            errorMessage = "当前没有可重连的会议会话"
            return
        }
        await runBusy {
            signalingClient.send(type: "client.reconnecting", payload: [:])
            try? await Task.sleep(nanoseconds: 250_000_000)
            let response = try await apiClient.reconnectMeeting(clientSessionId: clientSessionId)
            try await enterMeeting(response)
        }
    }

    func leaveMeeting() async {
        guard let clientSessionId = currentMeeting?.clientSessionId else {
            currentMeeting = nil
            return
        }
        await runBusy {
            try await apiClient.leaveMeeting(clientSessionId: clientSessionId)
            signalingClient.disconnect()
            liveKitAdapter.disconnect()
            currentMeeting = nil
            runtime = nil
            isMuted = false
            isScreenSharing = false
            await refreshLists()
        }
    }

    func toggleMute() async {
        guard let meetingNo = currentMeeting?.meetingNo else { return }
        let nextValue = !isMuted
        await runBusy {
            try await liveKitAdapter.setMicrophoneMuted(nextValue)
            runtime = try await apiClient.updateMute(meetingNo: meetingNo, muted: nextValue)
            isMuted = nextValue
            signalingClient.send(type: "client.mute_changed", payload: ["muted": String(nextValue)])
        }
    }
    func loadScreenShareSources() async -> Bool {
        if !PermissionService.hasScreenRecordingPermission() {
            _ = PermissionService.requestScreenRecordingPermission()
            guard PermissionService.hasScreenRecordingPermission() else {
                errorMessage = "屏幕录制权限尚未生效。如果系统设置里已经显示已授权，请完全退出远程会议后重新打开。"
                return false
            }
        }
        do {
            screenShareSources = try await liveKitAdapter.screenShareSources()
            if screenShareSources.isEmpty {
                errorMessage = "没有找到可共享的显示器或应用窗口"
                return false
            }
            return true
        } catch {
            errorMessage = "无法读取共享内容：\(error.localizedDescription)"
            return false
        }
    }

    func startScreenShare(source: LiveKitAdapter.ScreenShareSourceChoice) async {
        guard let meetingNo = currentMeeting?.meetingNo else { return }
        await runBusy {
            try await liveKitAdapter.startScreenShare(source: source)
            let response = try await apiClient.startScreenShare(meetingNo: meetingNo, scope: source.scope, sourceName: source.name)
            runtime = response.runtime
            isScreenSharing = true
            signalingClient.send(type: "client.screen_share_started", payload: ["scope": source.scope])
            if let replacedAccount = response.replacedAccount {
                errorMessage = "已替换 \(replacedAccount) 的屏幕共享"
            }
        }
    }

    func startScreenShare() async {
        guard await loadScreenShareSources(),
              let display = screenShareSources.first(where: { $0.scope == "SCREEN" }) ?? screenShareSources.first
        else { return }
        await startScreenShare(source: display)
    }

    func stopScreenShare() async {
        guard let meetingNo = currentMeeting?.meetingNo else { return }
        await runBusy {
            try await liveKitAdapter.stopScreenShare()
            runtime = try await apiClient.stopScreenShare(meetingNo: meetingNo)
            isScreenSharing = false
            signalingClient.send(type: "client.screen_share_stopped", payload: [:])
        }
    }

    func refreshLists() async {
        do {
            history = try await apiClient.meetingHistory()
            recordings = try await apiClient.recordings()
        } catch APIError.unauthorized {
            logout()
            errorMessage = "登录已失效，请重新登录"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadRecording(_ recording: ClientRecording) async {
        do {
            let data = try await apiClient.downloadRecording(id: recording.id)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = recording.fileName ?? "meeting-\(recording.meetingNo).mp4"
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            try data.write(to: destination, options: .atomic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshRuntime() async {
        guard let meetingNo = currentMeeting?.meetingNo else { return }
        do {
            runtime = try await apiClient.runtime(meetingNo: meetingNo)
        } catch {
            // Keep the meeting UI stable during transient runtime refresh failures.
        }
    }

    private func enterMeeting(_ response: JoinMeetingResponse) async throws {
        currentMeeting = response.meeting
        runtime = try? await apiClient.runtime(meetingNo: response.meeting.meetingNo)
        if let token = apiClient.accessToken {
            signalingClient.connect(baseURLString: baseURLString, token: token, meetingNo: response.meeting.meetingNo)
        }
        try await liveKitAdapter.connect(using: response.liveKit, microphoneEnabled: !isMuted)
    }

    private func handleSignalingEvent(_ event: SignalingEvent) async {
        switch event.type {
        case "server.connected", "server.member_joined", "server.member_left":
            await refreshRuntime()
        case "client.screen_share_started":
            guard event.account != currentUser?.account else {
                return
            }
            if isScreenSharing {
                await stopLocalScreenShareAfterReplacement(by: event.nickname ?? event.account ?? "其他参会人")
            }
            await liveKitAdapter.refreshRemoteScreenShareRepeatedly()
        case "client.screen_share_stopped":
            guard event.account != currentUser?.account else {
                return
            }
            await liveKitAdapter.refreshRemoteScreenShareRepeatedly()
        default:
            break
        }
    }

    private func rebuildMeetingParticipants(
        runtime: MeetingRuntimeState?,
        participantNames: [String: String],
        liveKitState: LiveKitAdapter.ConnectionState
    ) {
        if liveKitState == .connected {
            meetingParticipants = participantNames.map { account, nickname in
                runtime?.participants[account] ?? ParticipantRuntimeState(
                    account: account,
                    nickname: nickname,
                    muted: false,
                    networkQuality: "良好",
                    latencyMs: nil,
                    packetLossPercent: nil,
                    audioBitrateKbps: nil,
                    screenShareBitrateKbps: nil,
                    updatedAt: Date()
                )
            }.sorted { $0.nickname < $1.nickname }
        } else {
            meetingParticipants = runtime?.participants.values.sorted { $0.nickname < $1.nickname } ?? []
        }
    }

    private func stopLocalScreenShareAfterReplacement(by nickname: String) async {
        do {
            try await liveKitAdapter.stopScreenShare()
        } catch {
            errorMessage = error.localizedDescription
        }
        if let meetingNo = currentMeeting?.meetingNo {
            runtime = try? await apiClient.runtime(meetingNo: meetingNo)
        }
        isScreenSharing = false
        errorMessage = "你的屏幕共享已被 \(nickname) 的共享替换。"
    }

    private func runBusy(_ operation: () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}
