import Foundation
import Combine

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
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var isMuted = false
    @Published var isScreenSharing = false

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
    func startScreenShare() async {
        guard let meetingNo = currentMeeting?.meetingNo else { return }
        if !PermissionService.hasScreenRecordingPermission() {
            _ = PermissionService.requestScreenRecordingPermission()
            guard PermissionService.hasScreenRecordingPermission() else {
                errorMessage = "屏幕录制权限尚未生效。如果系统设置里已经显示已授权，请完全退出远程会议后重新打开。"
                return
            }
        }
        await runBusy {
            try await liveKitAdapter.startScreenShare(scope: "SCREEN", sourceName: "内建显示器")
            let response = try await apiClient.startScreenShare(meetingNo: meetingNo, scope: "SCREEN", sourceName: "内建显示器")
            runtime = response.runtime
            isScreenSharing = true
            signalingClient.send(type: "client.screen_share_started", payload: ["scope": "SCREEN"])
            if let replacedAccount = response.replacedAccount {
                errorMessage = "已替换 \(replacedAccount) 的屏幕共享"
            }
        }
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
