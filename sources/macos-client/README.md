# RemoteMeetingMac

macOS SwiftUI client for the remote meeting system.

Current scope:

- Login and logout.
- Create instant meeting.
- Join meeting by meeting number and password.
- Leave meeting.
- Report mute state.
- Start and stop screen-share state in backend.
- Connect WebSocket signaling.
- Connect to LiveKit with the Swift SDK.
- Publish and mute/unmute microphone audio.
- Publish and stop macOS main-screen sharing through LiveKit.

Local run:

```bash
cd sources/macos-client
swift package resolve
bash patch-livekit-sdk.sh
swift run
```

Default backend:

```text
http://localhost:8080
```

Notes:

- This package builds with Command Line Tools. A signed `.app` bundle and Xcode project can be added later.
- Screen sharing currently captures the main display. Window selection can be added next with LiveKit's `MacOSScreenCapturer` source APIs.
- LiveKit Swift SDK dependency is managed by Swift Package Manager.
- The app requests microphone permission before joining audio. Screen-recording permission is requested before screen sharing.

Verified:

```bash
swift package resolve
bash patch-livekit-sdk.sh
swift build
```

Build a local unsigned app bundle:

```bash
cd sources/macos-client
bash package-app.sh
open dist/RemoteMeetingMac.app
```

打包脚本会先修补 LiveKit 2.15.1 的 macOS 共享源枚举，使位于其他桌面空间或全屏空间的 Chrome 等窗口也能被列出并纳入整屏共享。

Development deployments may use a raw IP over HTTP/WS, so the bundled
`Info.plist` temporarily permits insecure transport. Production deployments
should use HTTPS/WSS and remove `NSAllowsArbitraryLoads`.

会议重连保留麦克风的静音选择，并重新同步服务端设备状态。屏幕共享在断线重连前停止采集和发布，重连后必须由用户重新选择并点击共享。此隐私策略覆盖 LiveKit 的快速和完整重连；本地运行及构建必须先执行 `patch-livekit-sdk.sh`，打包脚本会自动执行。SDK 补丁还会阻止自动重新发布屏幕视频或屏幕音频轨道，补丁无法匹配时构建准备步骤报错退出。

麦克风静音选择按服务地址、参会账号和会议 ID 持久化到本机 Application Support/MeetHarbor/MeetingDeviceStates。每次切换成功后立即原子写入，后端同步失败不影响已保存的选择；应用意外退出、正常离会或注销后，再进入同一会议时均在媒体连接前恢复。其他账号、服务或会议不继承该选择。只保存麦克风静音值，不保存令牌或屏幕共享源，屏幕共享仍需手动开启。读取记录失败时中止入会并显示错误，避免静音记录损坏后自动打开麦克风。

持久化回归检查：`python3 Tests/test_device_state_persistence.py`，覆盖写入后强制终止进程再读取、静音及取消静音、账号/会议/服务隔离、损坏记录和入会令牌账号解析。真实客户端验收：在两端入会后分别设置静音和取消静音，强制退出本端并重新打开、进入同一会议，检查本端按钮、远端收音与成员静音标记；共享桌面不应自动恢复。

重连隐私回归检查：`python3 tests/test_reconnect_privacy.py`。覆盖补丁重复执行、SDK 结构变化时拒绝继续，以及实际补丁清理函数对屏幕视频/音频、麦克风和采集停止失败的处理。真实网络验收需用两台客户端分别验证短暂断网、长时间断网和手动重连：麦克风静音/非静音各测一次；共享期间断网并切换页面，恢复后远端不得看到新页面，必须再次点击共享才发布。
