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
swift build
```

Build a local unsigned app bundle:

```bash
cd sources/macos-client
bash package-app.sh
open dist/RemoteMeetingMac.app
```

Development deployments may use a raw IP over HTTP/WS, so the bundled
`Info.plist` temporarily permits insecure transport. Production deployments
should use HTTPS/WSS and remove `NSAllowsArbitraryLoads`.
