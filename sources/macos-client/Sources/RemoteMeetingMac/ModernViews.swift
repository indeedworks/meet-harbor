import AppKit
import LiveKit
import SwiftUI

private enum AppSection: String, CaseIterable, Identifiable {
    case meetings
    case history
    case recordings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meetings: "会议"
        case .history: "历史"
        case .recordings: "录制"
        }
    }

    var icon: String {
        switch self {
        case .meetings: "video.fill"
        case .history: "clock.arrow.circlepath"
        case .recordings: "record.circle"
        }
    }
}

struct ModernMainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSection: AppSection = .meetings
    @State private var showingSettings = false

    var body: some View {
        Group {
            if let meeting = appState.currentMeeting, meeting.clientSessionId != nil {
                ModernInMeetingView(meeting: meeting)
            } else {
                HStack(spacing: 0) {
                    AppSidebar(selection: $selectedSection, showingSettings: $showingSettings)
                    Group {
                        switch selectedSection {
                        case .meetings:
                            ModernMeetingHomeView()
                        case .history:
                            ModernHistoryView()
                        case .recordings:
                            ModernRecordingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            ClientSettingsView()
                .environmentObject(appState)
        }
        .task {
            await appState.refreshLists()
        }
    }
}

private struct AppSidebar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selection: AppSection
    @Binding var showingSettings: Bool

    var body: some View {
        VStack(spacing: 10) {
            UserAvatar(name: appState.currentUser?.nickname ?? "用户", size: 44)
                .padding(.top, 20)
                .padding(.bottom, 10)

            ForEach(AppSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: section.icon)
                            .font(.system(size: 21, weight: .medium))
                        Text(section.title)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(selection == section ? Color.accentColor : Color.secondary)
                    .frame(width: 72, height: 62)
                    .background(selection == section ? Color.accentColor.opacity(0.09) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            SidebarIconButton(title: "设置", icon: "gearshape") {
                showingSettings = true
            }
            SidebarIconButton(title: "退出登录", icon: "rectangle.portrait.and.arrow.right") {
                appState.logout()
            }
            .padding(.bottom, 16)
        }
        .frame(width: 92)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.965, alpha: 1)))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.45))
                .frame(width: 1)
        }
    }
}

private struct SidebarIconButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundStyle(.secondary)
                .frame(width: 42, height: 38)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private enum HomeDialog: String, Identifiable {
    case join
    case instant
    case scheduled

    var id: String { rawValue }
}

struct ModernMeetingHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var dialog: HomeDialog?

    private var scheduledMeetings: [MeetingHistoryItem] {
        appState.history
            .filter { $0.status == "SCHEDULED" || $0.status == "WAITING" }
            .sorted { ($0.scheduledStartAt ?? .distantFuture) < ($1.scheduledStartAt ?? .distantFuture) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack {
                Spacer()
                HStack(spacing: 46) {
                    HomeActionButton(title: "加入会议", icon: "plus", tint: Color(red: 0.04, green: 0.42, blue: 0.96)) {
                        dialog = .join
                    }
                    HomeActionButton(title: "快速会议", icon: "bolt.fill", tint: Color(red: 0.03, green: 0.49, blue: 0.96)) {
                        dialog = .instant
                    }
                    HomeActionButton(title: "预约会议", icon: "calendar.badge.plus", tint: Color(red: 0.06, green: 0.65, blue: 0.50)) {
                        dialog = .scheduled
                    }
                }
                Spacer()
            }
            .frame(minWidth: 520, maxWidth: .infinity)

            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.45))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date.now.formatted(.dateTime.month().day()))
                        .font(.system(size: 34, weight: .semibold))
                    Text(Date.now.formatted(.dateTime.weekday(.wide)))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 76)
                .padding(.horizontal, 52)
                .padding(.bottom, 22)

                Divider()
                    .padding(.horizontal, 52)

                if scheduledMeetings.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "cup.and.saucer")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.accentColor.opacity(0.18))
                        Text("暂无预约会议")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(scheduledMeetings) { meeting in
                                ScheduledMeetingRow(meeting: meeting)
                            }
                        }
                        .padding(.horizontal, 52)
                        .padding(.top, 12)
                    }
                }
            }
            .frame(minWidth: 460, maxWidth: .infinity)
        }
        .sheet(item: $dialog) { dialog in
            switch dialog {
            case .join:
                JoinMeetingDialog()
                    .environmentObject(appState)
            case .instant:
                InstantMeetingDialog()
                    .environmentObject(appState)
            case .scheduled:
                ScheduledMeetingDialog()
                    .environmentObject(appState)
            }
        }
    }
}

private struct HomeActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 35, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 92)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: tint.opacity(0.18), radius: 10, y: 4)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: 112)
        }
        .buttonStyle(.plain)
    }
}

private struct ScheduledMeetingRow: View {
    let meeting: MeetingHistoryItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.topic)
                    .font(.system(size: 14, weight: .medium))
                Text(scheduledMeetingDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                copyMeetingNoToPasteboard(meeting.meetingNo)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("复制会议号")
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var scheduledMeetingDetail: String {
        guard let date = meeting.scheduledStartAt else {
            return "会议号 \(meeting.meetingNo)"
        }
        return "\(date.formatted(.dateTime.month().day().hour().minute())) · \(meeting.meetingNo)"
    }
}

private struct DialogScaffold<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
            content
        }
        .padding(28)
        .frame(width: 420)
    }
}

private struct JoinMeetingDialog: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var meetingNo = ""

    var body: some View {
        DialogScaffold(title: "加入会议") {
            TextField("会议号", text: $meetingNo)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button(appState.isBusy ? "加入中..." : "加入会议") {
                    Task {
                        await appState.joinMeeting(meetingNo: meetingNo)
                        if appState.currentMeeting?.clientSessionId != nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(appState.isBusy || meetingNo.isEmpty)
            }
        }
    }
}

private struct InstantMeetingDialog: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var topic = "即时会议"

    var body: some View {
        DialogScaffold(title: "快速会议") {
            TextField("会议主题", text: $topic)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button(appState.isBusy ? "正在进入..." : "开始会议") {
                    Task {
                        await appState.startInstantMeeting(topic: topic)
                        if appState.currentMeeting?.clientSessionId != nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(appState.isBusy || topic.isEmpty)
            }
        }
    }
}

private struct ScheduledMeetingDialog: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var topic = "预约会议"
    @State private var scheduledAt = Date.now.addingTimeInterval(3600)

    var body: some View {
        DialogScaffold(title: "预约会议") {
            TextField("会议主题", text: $topic)
                .textFieldStyle(.roundedBorder)
            DatePicker("开始时间", selection: $scheduledAt, in: Date.now...)
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button(appState.isBusy ? "预约中..." : "完成预约") {
                    Task {
                        await appState.createScheduledMeeting(topic: topic, scheduledStartAt: scheduledAt)
                        if appState.lastCreatedMeeting != nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(appState.isBusy || topic.isEmpty)
            }
        }
    }
}

struct ModernInMeetingView: View {
    @EnvironmentObject private var appState: AppState
    let meeting: MeetingDetail
    @State private var showingMembers = false

    var body: some View {
        VStack(spacing: 0) {
            MeetingTopBar(meeting: meeting, showingMembers: $showingMembers)
            ZStack(alignment: .trailing) {
                MeetingStage(meeting: meeting)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showingMembers {
                    MemberPanel()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            MeetingControlBar(meeting: meeting, showingMembers: $showingMembers)
        }
        .background(Color(nsColor: NSColor(calibratedWhite: 0.985, alpha: 1)))
        .task(id: meeting.meetingNo) {
            while !Task.isCancelled {
                await appState.refreshRuntime()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showingMembers)
    }
}

private struct MeetingTopBar: View {
    @EnvironmentObject private var appState: AppState
    let meeting: MeetingDetail
    @Binding var showingMembers: Bool

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.topic)
                    .font(.system(size: 15, weight: .semibold))
                Text("会议号 \(meeting.meetingNo)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                copyMeetingNoToPasteboard(meeting.meetingNo)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("复制会议号")
            MeetingDurationView(startedAt: meeting.startedAt)
            NetworkStatusView()
            Spacer()
            Button {
                showingMembers.toggle()
            } label: {
                Label("成员 (\(appState.meetingParticipants.count))", systemImage: "person.2")
            }
            .buttonStyle(.plain)
            .help("查看参会成员")
            Button {
                Task { await appState.reconnectCurrentMeeting() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17))
            }
            .buttonStyle(.plain)
            .help("重新连接")
            Button {
                ScreenShareFullScreenPresenter.show(appState: appState)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 17))
            }
            .buttonStyle(.plain)
            .help("全屏观看共享")
            .disabled(appState.liveKitAdapter.remoteScreenShareTrack == nil)
        }
        .foregroundStyle(Color(nsColor: .labelColor))
        .padding(.horizontal, 22)
        .frame(height: 66)
        .background(Color.white)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct MeetingDurationView: View {
    let startedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(durationText(at: context.date))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
        }
    }

    private func durationText(at now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(startedAt ?? now)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct NetworkStatusView: View {
    @EnvironmentObject private var appState: AppState

    private var quality: String {
        guard let account = appState.currentUser?.account else { return "良好" }
        return appState.runtime?.participants[account]?.networkQuality ?? "良好"
    }

    var body: some View {
        Label(quality, systemImage: "chart.bar.fill")
            .labelStyle(.iconOnly)
            .foregroundStyle(quality == "较差" ? Color.red : quality == "一般" ? Color.orange : Color.green)
            .help("网络质量：\(quality)")
    }
}

private struct MeetingStage: View {
    @EnvironmentObject private var appState: AppState
    let meeting: MeetingDetail

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(calibratedWhite: 0.985, alpha: 1))
            if let track = appState.liveKitAdapter.remoteScreenShareTrack {
                SwiftUIVideoView(track, layoutMode: .fit)
                    .background(Color.black)
                    .overlay(alignment: .topLeading) {
                        Label(appState.liveKitAdapter.remoteScreenShareOwner ?? "屏幕共享", systemImage: "rectangle.on.rectangle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.62))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(14)
                    }
            } else {
                ParticipantStage(meeting: meeting)
            }
        }
    }
}

private struct ParticipantStage: View {
    @EnvironmentObject private var appState: AppState
    let meeting: MeetingDetail

    private var participants: [ParticipantRuntimeState] {
        let values = appState.meetingParticipants
        if values.isEmpty, let user = appState.currentUser {
            return [ParticipantRuntimeState(
                account: user.account,
                nickname: user.nickname,
                muted: appState.isMuted,
                networkQuality: "良好",
                latencyMs: nil,
                packetLossPercent: nil,
                audioBitrateKbps: nil,
                screenShareBitrateKbps: nil,
                updatedAt: .now
            )]
        }
        return values
    }

    var body: some View {
        VStack(spacing: 18) {
            if let speaker = participants.first(where: { !$0.muted }) {
                Text("正在讲话：\(speaker.nickname)")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            LazyVGrid(columns: participantColumns, spacing: 34) {
                ForEach(participants, id: \.account) { participant in
                    ParticipantTile(participant: participant)
                }
            }
            .frame(maxWidth: 760)
        }
        .padding(40)
    }

    private var participantColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 28), count: min(max(participants.count, 1), 4))
    }
}

private struct ParticipantTile: View {
    let participant: ParticipantRuntimeState

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                UserAvatar(name: participant.nickname, size: 82)
                Image(systemName: participant.muted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(participant.muted ? Color.red : Color.white)
                    .frame(width: 24, height: 24)
                    .background(participant.muted ? Color.white : Color.green)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            Text(participant.nickname)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
        }
        .frame(minWidth: 130)
    }
}

private struct UserAvatar: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.11))
            .clipShape(Circle())
    }
}

private struct MemberPanel: View {
    @EnvironmentObject private var appState: AppState

    private var participants: [ParticipantRuntimeState] {
        appState.meetingParticipants
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("参会成员 (\(participants.count))")
                .font(.system(size: 16, weight: .semibold))
                .padding(20)
            Divider()
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(participants, id: \.account) { participant in
                        HStack(spacing: 11) {
                            UserAvatar(name: participant.nickname, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.nickname)
                                    .font(.system(size: 13, weight: .medium))
                                Text(participant.networkQuality)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: participant.muted ? "mic.slash" : "mic")
                                .foregroundStyle(participant.muted ? Color.red : Color.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 286)
        .frame(maxHeight: .infinity)
        .background(Color.white)
        .shadow(color: .black.opacity(0.09), radius: 14, x: -4)
    }
}

private struct MeetingControlBar: View {
    @EnvironmentObject private var appState: AppState
    let meeting: MeetingDetail
    @Binding var showingMembers: Bool
    @State private var showingScreenShareSources = false

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            MeetingControlButton(
                title: appState.isMuted ? "解除静音" : "静音",
                icon: appState.isMuted ? "mic.slash.fill" : "mic.fill",
                activeColor: appState.isMuted ? .red : .primary
            ) {
                Task { await appState.toggleMute() }
            }
            MeetingControlButton(
                title: appState.isScreenSharing ? "停止共享" : "共享屏幕",
                icon: appState.isScreenSharing ? "rectangle.slash" : "rectangle.on.rectangle",
                activeColor: appState.isScreenSharing ? .green : .primary
            ) {
                Task {
                    if appState.isScreenSharing {
                        await appState.stopScreenShare()
                    } else if await appState.loadScreenShareSources() {
                        showingScreenShareSources = true
                    }
                }
            }
            MeetingControlButton(title: "复制会议号", icon: "doc.on.doc", activeColor: .primary) {
                copyMeetingNoToPasteboard(meeting.meetingNo)
            }
            MeetingControlButton(title: "成员", icon: "person.2", activeColor: showingMembers ? .accentColor : .primary) {
                showingMembers.toggle()
            }
            MeetingControlButton(title: "重连", icon: "arrow.clockwise", activeColor: .primary) {
                Task { await appState.reconnectCurrentMeeting() }
            }
            Spacer()
            Button(role: .destructive) {
                Task { await appState.leaveMeeting() }
            } label: {
                Label("离开会议", systemImage: "rectangle.portrait.and.arrow.forward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 22)
        }
        .frame(height: 84)
        .background(Color.white)
        .overlay(alignment: .top) { Divider() }
        .sheet(isPresented: $showingScreenShareSources) {
            ScreenShareSourcePicker(isPresented: $showingScreenShareSources)
                .environmentObject(appState)
        }
    }

}

private struct ScreenShareSourcePicker: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择共享内容")
                .font(.title2.weight(.semibold))
            Text("可以共享整块显示器，也可以只共享 Chrome 等应用窗口。")
                .foregroundStyle(.secondary)
            List(appState.screenShareSources) { source in
                Button {
                    isPresented = false
                    Task { await appState.startScreenShare(source: source) }
                } label: {
                    Label(source.name, systemImage: source.scope == "WINDOW" ? "macwindow" : "display")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 560, height: 460)
    }
}

private func copyMeetingNoToPasteboard(_ meetingNo: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(meetingNo, forType: .string)
}

private struct MeetingControlButton: View {
    let title: String
    let icon: String
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundStyle(activeColor)
            .frame(width: 88, height: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ModernHistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ModernListPage(title: "历史会议", subtitle: "你参与过的会议") {
            if appState.history.isEmpty {
                ContentUnavailableView("暂无历史会议", systemImage: "clock")
            } else {
                List(appState.history) { item in
                    HStack(spacing: 14) {
                        Image(systemName: "video")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 34, height: 34)
                            .background(Color.accentColor.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.topic).font(.headline)
                            Text("会议号 \(item.meetingNo) · \(item.durationSeconds / 60) 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(meetingStatusText(item.status))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 7)
                }
                .listStyle(.inset)
            }
        }
    }
}

struct ModernRecordingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ModernListPage(title: "录制文件", subtitle: "你参与过的会议录制") {
            if appState.recordings.isEmpty {
                ContentUnavailableView("暂无录制文件", systemImage: "record.circle")
            } else {
                List(appState.recordings) { recording in
                    HStack(spacing: 14) {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(Color.orange)
                            .frame(width: 34, height: 34)
                            .background(Color.orange.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recording.meetingTopic).font(.headline)
                            Text("会议号 \(recording.meetingNo) · \(ByteCountFormatter.string(fromByteCount: recording.fileSizeBytes, countStyle: .file))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(recording.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("下载") {
                            Task { await appState.downloadRecording(recording) }
                        }
                        .disabled(recording.status != "COMPLETED")
                    }
                    .padding(.vertical, 7)
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct ModernListPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 27, weight: .semibold))
                    Text(subtitle).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(Color.white)
            .overlay(alignment: .bottom) { Divider() }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClientSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(title: "设置") {
            VStack(alignment: .leading, spacing: 7) {
                Text("服务端地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("http://localhost:8080", text: $appState.baseURLString)
                    .textFieldStyle(.roundedBorder)
            }
            PermissionStatusView()
            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private func meetingStatusText(_ status: String) -> String {
    switch status {
    case "IN_PROGRESS": "进行中"
    case "SCHEDULED", "WAITING": "已预约"
    case "ENDED": "已结束"
    case "CANCELLED": "已取消"
    default: status
    }
}
