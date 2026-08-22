# macOS Client API V1

This document is the baseline API contract for the macOS client. It reflects the current backend implementation and marks unfinished endpoints explicitly.

## 1. Base Rules

Default local backend:

```text
http://localhost:8080
```

All HTTP APIs return the same envelope:

```json
{
  "code": 0,
  "message": "OK",
  "data": {},
  "timestamp": "2026-07-11T10:28:36.32159+08:00"
}
```

Success:

```text
code = 0
message = OK
```

Common error behavior:

```json
{
  "code": 400,
  "message": "会议不存在",
  "data": null,
  "timestamp": "2026-07-11T10:28:36.32159+08:00"
}
```

Authenticated APIs require:

```http
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Date/time fields are ISO-8601 strings.

## 2. Login

### Login

```http
POST /api/auth/login
```

Request:

```json
{
  "account": "admin",
  "password": "admin123"
}
```

Response `data`:

```json
{
  "accessToken": "jwt-token",
  "expiresAt": "2026-07-11T04:28:36Z",
  "account": "admin",
  "nickname": "系统管理员",
  "role": "ADMIN"
}
```

Client handling:

- Store `accessToken` securely in Keychain.
- Use `expiresAt` to refresh UX state. There is no refresh-token API yet; expired token requires login again.

### Change Password

```http
POST /api/auth/change-password
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "oldPassword": "admin123",
  "newPassword": "new-password"
}
```

Response:

```json
{
  "code": 0,
  "message": "OK",
  "data": null,
  "timestamp": "2026-07-11T10:28:36.32159+08:00"
}
```

## 3. Meetings

### Create Instant Meeting

```http
POST /api/client/meetings/instant
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "topic": "产品周会"
}
```

Notes:

- Creator is the host.
- Meetings do not use a password; the meeting number is sufficient to join.
- Meeting enters `IN_PROGRESS` immediately.

Response `data`:

```json
{
  "id": 7,
  "topic": "产品周会",
  "meetingNo": "67477693",
  "invitationLink": "http://localhost:8080/join?meetingNo=67477693",
  "status": "IN_PROGRESS",
  "hostName": "系统管理员",
  "scheduledStartAt": "2026-07-11T10:28:26.123+08:00",
  "startedAt": "2026-07-11T10:28:26.123+08:00",
  "clientSessionId": null
}
```

### Create Scheduled Meeting

```http
POST /api/client/meetings/scheduled
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "topic": "项目评审",
  "scheduledStartAt": "2026-07-12T10:00:00+08:00"
}
```

Response `data`: same as create instant meeting.

Notes:

- Meeting status is `SCHEDULED`.
- Joining this meeting will change status to `IN_PROGRESS`.

### Join Meeting

```http
POST /api/client/meetings/join
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "meetingNo": "67477693"
}
```

Response `data`:

```json
{
  "meeting": {
    "id": 7,
    "topic": "产品周会",
    "meetingNo": "67477693",
    "invitationLink": "http://localhost:8080/join?meetingNo=67477693",
    "status": "IN_PROGRESS",
    "hostName": "系统管理员",
    "scheduledStartAt": "2026-07-11T10:28:26.123+08:00",
    "startedAt": "2026-07-11T10:28:26.123+08:00",
    "clientSessionId": "6b82a0be-5bea-4acd-8aaa-18a32ea23de8"
  },
  "liveKit": {
    "url": "ws://localhost:7880",
    "roomName": "meeting-67477693",
    "participantToken": "livekit-jwt-token",
    "expiresAt": "2026-07-11T04:28:26Z"
  }
}
```

Client handling:

- Store `clientSessionId` in memory for current meeting.
- Use `liveKit.url`, `liveKit.roomName`, and `liveKit.participantToken` to connect to LiveKit.
- Do not persist `participantToken`; request a new one through reconnect when needed.

### Leave Meeting

```http
POST /api/client/meetings/leave
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "clientSessionId": "6b82a0be-5bea-4acd-8aaa-18a32ea23de8"
}
```

Response:

```json
{
  "code": 0,
  "message": "OK",
  "data": null,
  "timestamp": "2026-07-11T10:28:36.32159+08:00"
}
```

Notes:

- If this is the last active session, backend ends the meeting and deletes the LiveKit room.

### Reconnect Meeting

```http
POST /api/client/meetings/reconnect
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "clientSessionId": "6b82a0be-5bea-4acd-8aaa-18a32ea23de8"
}
```

Response `data`: same as join meeting.

Client handling:

- Preserve current mute state locally.
- Call reconnect after network recovery.
- Use returned LiveKit token to reconnect to current live meeting.
- Do not play historical audio after reconnect.

### My Meeting History

```http
GET /api/client/meetings/history
Authorization: Bearer <accessToken>
```

Response `data`:

```json
[
  {
    "id": 7,
    "topic": "产品周会",
    "meetingNo": "67477693",
    "status": "ENDED",
    "startedAt": "2026-07-11T10:28:26.123+08:00",
    "endedAt": "2026-07-11T10:58:26.123+08:00",
    "durationSeconds": 1800
  }
]
```

## 4. Meeting Runtime

Runtime state is currently kept in backend memory. It is suitable for V1 single-node development, but not yet Redis-backed.

### Get Runtime State

```http
GET /api/client/meetings/{meetingNo}/runtime
Authorization: Bearer <accessToken>
```

Response `data`:

```json
{
  "meetingNo": "67477693",
  "participants": {
    "admin": {
      "account": "admin",
      "nickname": "系统管理员",
      "muted": true,
      "networkQuality": "一般",
      "latencyMs": 86,
      "packetLossPercent": 1.5,
      "audioBitrateKbps": 42,
      "screenShareBitrateKbps": 900,
      "updatedAt": "2026-07-11T10:28:26.123+08:00"
    }
  },
  "screenShare": {
    "active": true,
    "account": "admin",
    "nickname": "系统管理员",
    "scope": "SCREEN",
    "sourceName": "内建显示器",
    "startedAt": "2026-07-11T10:28:26.123+08:00"
  },
  "updatedAt": "2026-07-11T10:28:26.123+08:00"
}
```

### Update Mute State

```http
POST /api/client/meetings/{meetingNo}/mute
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "muted": true
}
```

Response `data`: runtime state.

### Report Network Quality

```http
POST /api/client/meetings/{meetingNo}/network-quality
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "quality": "一般",
  "latencyMs": 86,
  "packetLossPercent": 1.5,
  "audioBitrateKbps": 42,
  "screenShareBitrateKbps": 900
}
```

Allowed `quality` values for client UI:

```text
良好
一般
较差
```

Response `data`: runtime state.

### Start Screen Share

```http
POST /api/client/meetings/{meetingNo}/screen-share/start
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "scope": "SCREEN",
  "sourceName": "内建显示器"
}
```

Allowed `scope` values for V1:

```text
SCREEN
WINDOW
```

Response `data`:

```json
{
  "runtime": {},
  "replacedAccount": "zhangsan"
}
```

Notes:

- `replacedAccount` is `null` when no previous sharer was replaced.
- macOS client should show a message if its own sharing is replaced by another user. WebSocket push for this is not complete yet.

### Stop Screen Share

```http
POST /api/client/meetings/{meetingNo}/screen-share/stop
Authorization: Bearer <accessToken>
```

Response `data`: runtime state.

## 5. WebSocket Signaling

Endpoint:

```text
ws://localhost:8080/ws/signaling?token=<accessToken>&meetingNo=<meetingNo>
```

Connection success event sent to current client:

```json
{
  "type": "server.connected",
  "meetingNo": "67477693",
  "account": "admin",
  "serverTime": "2026-07-11T10:28:26.123+08:00"
}
```

Member joined event sent to other clients:

```json
{
  "type": "server.member_joined",
  "meetingNo": "67477693",
  "account": "admin",
  "nickname": "系统管理员",
  "serverTime": "2026-07-11T10:28:26.123+08:00"
}
```

Member left event sent to other clients:

```json
{
  "type": "server.member_left",
  "meetingNo": "67477693",
  "account": "admin",
  "serverTime": "2026-07-11T10:28:26.123+08:00"
}
```

Client may send any JSON event:

```json
{
  "type": "client.mute_changed",
  "muted": true
}
```

Other clients receive:

```json
{
  "type": "client.mute_changed",
  "meetingNo": "67477693",
  "account": "admin",
  "nickname": "系统管理员",
  "payload": {
    "type": "client.mute_changed",
    "muted": true
  },
  "serverTime": "2026-07-11T10:28:26.123+08:00"
}
```

Current limitations:

- Event names are not yet strictly validated.
- Server does not yet persist WebSocket events.
- Dedicated server events for screen-share replacement, speaker highlight, and recording state are still pending.

## 6. LiveKit

The macOS client does not call LiveKit server APIs directly. It only uses the connection fields returned from join/reconnect:

```json
{
  "url": "ws://localhost:7880",
  "roomName": "meeting-67477693",
  "participantToken": "livekit-jwt-token",
  "expiresAt": "2026-07-11T04:28:26Z"
}
```

Client responsibilities:

- Connect to `url` with `participantToken`.
- Publish microphone audio track.
- Publish screen/window track when sharing.
- Do not publish camera video in V1.
- Prefer audio continuity under weak network.

Backend responsibilities already implemented:

- Generate LiveKit participant token.
- Create room before join.
- Delete room when meeting ends.
- Receive LiveKit webhook events.

## 7. Recordings

### My Recordings

```http
GET /api/client/recordings
Authorization: Bearer <accessToken>
```

Response `data`:

```json
[
  {
    "id": 1,
    "meetingTopic": "产品周会",
    "meetingNo": "67477693",
    "status": "COMPLETED",
    "fileName": "67477693.mp4",
    "fileSizeBytes": 104857600,
    "createdAt": "2026-07-11T10:28:26.123+08:00",
    "expiredAt": "2026-07-18T10:28:26.123+08:00"
  }
]
```

Current limitations:

- Client recording download API is not implemented yet.
- Start/stop recording APIs are not implemented yet.
- LiveKit Egress or FFmpeg recording pipeline is not implemented yet.

Recording statuses:

```text
NOT_STARTED
RECORDING
PROCESSING
COMPLETED
FAILED
EXPIRED
DELETED
```

## 8. Status Values

Meeting statuses:

```text
SCHEDULED
WAITING
IN_PROGRESS
ENDED
CANCELLED
```

Meeting types:

```text
INSTANT
SCHEDULED
```

Meeting roles:

```text
HOST
PARTICIPANT
```

User roles:

```text
ADMIN
USER
```

## 9. Recommended macOS Client Flow

### Login

1. Call `POST /api/auth/login`.
2. Store `accessToken` in Keychain.
3. Enter home page.

### Create Instant Meeting

1. Call `POST /api/client/meetings/instant`.
2. Show invitation info.
3. Call `POST /api/client/meetings/join` if the creator should enter immediately.
4. Connect WebSocket signaling.
5. Connect LiveKit.

### Join Meeting

1. Check microphone permission locally.
2. Check screen-recording permission before screen share, not necessarily before audio-only join.
3. Call `POST /api/client/meetings/join`.
4. Save `clientSessionId` in memory.
5. Connect WebSocket signaling.
6. Connect LiveKit.
7. Publish microphone track.

### Mute / Unmute

1. Mute/unmute local microphone track in LiveKit.
2. Call `POST /api/client/meetings/{meetingNo}/mute`.
3. Send WebSocket event `client.mute_changed`.

### Screen Share

1. Check macOS screen-recording permission.
2. Let user choose screen/window.
3. Call `POST /api/client/meetings/{meetingNo}/screen-share/start`.
4. If successful, publish screen/window track to LiveKit.
5. On stop, unpublish screen/window track and call stop API.

### Network Reconnect

1. Detect LiveKit/WebSocket/network disconnection.
2. Keep local mute state.
3. Call `POST /api/client/meetings/reconnect`.
4. Reconnect WebSocket.
5. Reconnect LiveKit with the new participant token.
6. Resume current live meeting only.

### Leave Meeting

1. Stop screen share if active.
2. Disconnect LiveKit.
3. Close WebSocket.
4. Call `POST /api/client/meetings/leave`.
5. Clear in-memory `clientSessionId`.

## 10. Pending API Work Before Full V1

These are not ready yet and should not be assumed by the macOS client:

- Client download recording file.
- Host start/stop cloud recording.
- Dedicated recording status push.
- Strict WebSocket event schema.
- Speaker highlight event.
- Server-side weak-network downgrade command.
- Redis-backed runtime state for multi-backend deployment.
- Client app version / crash log upload API.
- Auto-update metadata API.
