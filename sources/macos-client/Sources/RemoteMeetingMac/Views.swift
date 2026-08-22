import SwiftUI
import LiveKit
import AppKit
import Combine

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                ModernMainView()
            } else {
                LoginView()
            }
        }
        .alert("提示", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("好") {
                appState.errorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var account = "admin"
    @State private var password = "admin123"

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("远程会议")
                    .font(.system(size: 30, weight: .semibold))
                Text("macOS 客户端")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                TextField("服务端地址", text: $appState.baseURLString)
                    .textFieldStyle(.roundedBorder)
                TextField("账号", text: $account)
                    .textFieldStyle(.roundedBorder)
                SecureField("密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task {
                        await appState.login(account: account, password: password)
                    }
                } label: {
                    Label(appState.isBusy ? "登录中" : "登录", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isBusy || account.isEmpty || password.isEmpty)
            }
            .frame(width: 360)
        }
        .padding(40)
    }
}

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSection = "home"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Label("会议", systemImage: "person.2.wave.2")
                    .tag("home")
                Label("历史会议", systemImage: "clock.arrow.circlepath")
                    .tag("history")
                Label("录制文件", systemImage: "record.circle")
                    .tag("recordings")
            }
            .navigationSplitViewColumnWidth(180)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Button {
                        appState.logout()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        } detail: {
            switch selectedSection {
            case "history":
                HistoryView()
            case "recordings":
                RecordingsView()
            default:
                MeetingHomeView()
            }
        }
        .task {
            await appState.refreshLists()
        }
    }
}

struct MeetingHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var topic = "即时会议"
    @State private var joinMeetingNo = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "会议", subtitle: appState.currentMeeting == nil ? "创建或加入一场远程音频会议" : "会议正在进行")

            if let meeting = appState.currentMeeting, meeting.clientSessionId != nil {
                InMeetingView(meeting: meeting)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    FormSection(title: "创建即时会议", systemImage: "plus.circle") {
                        TextField("会议主题", text: $topic)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            Task {
                                await appState.createInstantMeeting(topic: topic)
                            }
                        } label: {
                            Label("创建会议", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.isBusy || topic.isEmpty)

                        if let meeting = appState.currentMeeting, meeting.clientSessionId == nil {
                            InvitationView(meeting: meeting)
                            Button {
                                joinMeetingNo = meeting.meetingNo
                                Task {
                                    await appState.joinMeeting(meetingNo: joinMeetingNo)
                                }
                            } label: {
                                Label("进入会议", systemImage: "arrow.right")
                            }
                        }
                    }

                    FormSection(title: "加入会议", systemImage: "arrow.down.forward.circle") {
                        TextField("会议号", text: $joinMeetingNo)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            Task {
                                await appState.joinMeeting(meetingNo: joinMeetingNo)
                            }
                        } label: {
                            Label("加入", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.isBusy || joinMeetingNo.isEmpty)

                        PermissionStatusView()
                    }
                }
                .padding(24)
            }
        }
    }
}

struct InMeetingView: View {
    @EnvironmentObject private var appState: AppState
    let meeting: MeetingDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(meeting.topic)
                        .font(.title2.weight(.semibold))
                    Text("会议号 \(meeting.meetingNo)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: appState.liveKitAdapter.state.rawValue, systemImage: "dot.radiowaves.left.and.right")
                StatusPill(text: appState.signalingClient.isConnected ? "信令已连接" : "信令未连接", systemImage: "bolt.horizontal")
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await appState.toggleMute()
                    }
                } label: {
                    Label(appState.isMuted ? "解除静音" : "静音", systemImage: appState.isMuted ? "mic.slash.fill" : "mic.fill")
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button {
                    Task {
                        appState.isScreenSharing ? await appState.stopScreenShare() : await appState.startScreenShare()
                    }
                } label: {
                    Label(appState.isScreenSharing ? "停止共享" : "共享屏幕", systemImage: appState.isScreenSharing ? "rectangle.slash" : "rectangle.on.rectangle")
                }

                Button {
                    Task {
                        await appState.reconnectCurrentMeeting()
                    }
                } label: {
                    Label("重连", systemImage: "arrow.clockwise")
                }

                Spacer()

                Button(role: .destructive) {
                    Task {
                        await appState.leaveMeeting()
                    }
                } label: {
                    Label("离开会议", systemImage: "xmark.circle")
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 18) {
                ScreenShareStageView()
                    .frame(minWidth: 520, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity)
                VStack(spacing: 18) {
                    ParticipantsView(runtime: appState.runtime)
                    SignalingEventsView()
                }
                .frame(width: 300)
            }
        }
        .padding(24)
    }
}

struct ScreenShareStageView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("屏幕共享", systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                Spacer()
                if let owner = appState.liveKitAdapter.remoteScreenShareOwner {
                    Text(owner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    ScreenShareFullScreenPresenter.show(appState: appState)
                } label: {
                    Label("全屏", systemImage: "arrow.up.left.and.arrow.down.right")
                        .labelStyle(.iconOnly)
                }
                .help("全屏观看")
                .disabled(appState.liveKitAdapter.remoteScreenShareTrack == nil)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor))
                if let track = appState.liveKitAdapter.remoteScreenShareTrack {
                    SwiftUIVideoView(track, layoutMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: appState.isScreenSharing ? "rectangle.on.rectangle" : "display")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(appState.isScreenSharing ? "你正在共享屏幕" : "暂无屏幕共享")
                            .font(.headline)
                        Text(appState.isScreenSharing ? "其他参会人会看到你的屏幕" : "有人开始共享后会显示在这里")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ScreenShareFullScreenView: View {
    @EnvironmentObject private var appState: AppState
    let onClose: () -> Void

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let track = appState.liveKitAdapter.remoteScreenShareTrack {
                SwiftUIVideoView(track, layoutMode: .fit)
                    .ignoresSafeArea()
            } else {
                Text("屏幕共享已结束")
                    .foregroundStyle(.white)
            }

            Button {
                onClose()
            } label: {
                Label("退出全屏", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .padding(18)
        }
        .onExitCommand {
            onClose()
        }
    }
}

enum ScreenShareFullScreenPresenter {
    @MainActor private static var window: NSWindow?
    @MainActor private static var closeObserver: NSObjectProtocol?
    @MainActor private static var trackObserver: AnyCancellable?

    @MainActor
    static func show(appState: AppState) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let screen = NSApp.keyWindow?.screen ?? NSApp.mainWindow?.screen ?? NSScreen.main
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: screenFrame.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let controller = NSHostingController(
            rootView: ScreenShareFullScreenView(onClose: { [weak window] in
                window?.close()
            })
            .environmentObject(appState)
        )
        window.title = "屏幕共享"
        window.level = .screenSaver
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.setFrame(screenFrame, display: true)
        window.makeKeyAndOrderFront(nil)

        trackObserver = appState.liveKitAdapter.$remoteScreenShareTrack
            .receive(on: RunLoop.main)
            .sink { [weak window] track in
                if track == nil {
                    window?.close()
                }
            }

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.window = nil
                if let closeObserver {
                    NotificationCenter.default.removeObserver(closeObserver)
                    self.closeObserver = nil
                }
                self.trackObserver = nil
            }
        }
        self.window = window
    }
}

struct ParticipantsView: View {
    let runtime: MeetingRuntimeState?

    var body: some View {
        FormSection(title: "参会人", systemImage: "person.2") {
            if let participants = runtime?.participants.values.sorted(by: { $0.nickname < $1.nickname }), !participants.isEmpty {
                ForEach(participants, id: \.account) { participant in
                    HStack {
                        Image(systemName: participant.muted ? "mic.slash" : "mic")
                        VStack(alignment: .leading) {
                            Text(participant.nickname)
                            Text(participant.networkQuality)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } else {
                Text("暂无运行态数据")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SignalingEventsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        FormSection(title: "信令事件", systemImage: "bolt.horizontal.circle") {
            if appState.signalingClient.events.isEmpty {
                Text("暂无事件")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.signalingClient.events) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.type)
                                    .lineLimit(1)
                                Text(event.account ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "历史会议", subtitle: "你参与过的会议")
            List(appState.history) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.topic)
                        .font(.headline)
                    Text("会议号 \(item.meetingNo) · \(item.status) · \(item.durationSeconds) 秒")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .overlay {
                if appState.history.isEmpty {
                    ContentUnavailableView("暂无历史会议", systemImage: "clock")
                }
            }
        }
    }
}

struct RecordingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "录制文件", subtitle: "当前后端只支持列表，下载接口尚未实现")
            List(appState.recordings) { recording in
                VStack(alignment: .leading, spacing: 5) {
                    Text(recording.meetingTopic)
                        .font(.headline)
                    Text("\(recording.meetingNo) · \(recording.status) · \(ByteCountFormatter.string(fromByteCount: recording.fileSizeBytes, countStyle: .file))")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .overlay {
                if appState.recordings.isEmpty {
                    ContentUnavailableView("暂无录制文件", systemImage: "record.circle")
                }
            }
        }
    }
}

struct HeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.regularMaterial)
    }
}

struct FormSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InvitationView: View {
    let meeting: MeetingDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("会议信息")
                .font(.headline)
            Text("主题：\(meeting.topic)")
            Text("会议号：\(meeting.meetingNo)")
            Text(meeting.invitationLink)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.callout)
        .textSelection(.enabled)
    }
}

struct PermissionStatusView: View {
    @State private var microphoneStatus = PermissionService.microphoneStatusText()
    @State private var screenAllowed = PermissionService.hasScreenRecordingPermission()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("权限检查")
                .font(.headline)
            HStack {
                Text("麦克风")
                Spacer()
                Text(microphoneStatus)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("屏幕录制")
                Spacer()
                Text(screenAllowed ? "已授权" : "未授权")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("请求麦克风权限") {
                    Task {
                        _ = await PermissionService.requestMicrophonePermission()
                        refresh()
                    }
                }
                Button("请求屏幕录制权限") {
                    _ = PermissionService.requestScreenRecordingPermission()
                    refresh()
                }
                Button("重新检查") {
                    refresh()
                }
            }
            if !screenAllowed {
                Text("如果系统设置中已经授权但这里仍显示未授权，请退出并重新打开应用，或移除旧的“远程会议”权限项后重新授权。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        microphoneStatus = PermissionService.microphoneStatusText()
        screenAllowed = PermissionService.hasScreenRecordingPermission()
    }
}

struct StatusPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .clipShape(Capsule())
    }
}
