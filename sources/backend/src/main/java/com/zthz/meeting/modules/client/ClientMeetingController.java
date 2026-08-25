package com.zthz.meeting.modules.client;

import com.zthz.meeting.common.ApiResponse;
import com.zthz.meeting.modules.client.ClientMeetingService.ClientRecordingResponse;
import com.zthz.meeting.modules.client.ClientMeetingService.CreateMeetingRequest;
import com.zthz.meeting.modules.client.ClientMeetingService.CreateScheduledMeetingRequest;
import com.zthz.meeting.modules.client.ClientMeetingService.JoinMeetingRequest;
import com.zthz.meeting.modules.client.ClientMeetingService.JoinMeetingResponse;
import com.zthz.meeting.modules.client.ClientMeetingService.LeaveMeetingRequest;
import com.zthz.meeting.modules.client.ClientMeetingService.MeetingDetailResponse;
import com.zthz.meeting.modules.client.ClientMeetingService.MeetingHistoryResponse;
import com.zthz.meeting.modules.client.ClientMeetingService.ReconnectMeetingRequest;
import com.zthz.meeting.modules.client.ClientMeetingRuntimeService.MeetingRuntimeState;
import com.zthz.meeting.modules.client.ClientMeetingRuntimeService.MuteStateRequest;
import com.zthz.meeting.modules.client.ClientMeetingRuntimeService.NetworkQualityRequest;
import com.zthz.meeting.modules.client.ClientMeetingRuntimeService.ScreenShareResponse;
import com.zthz.meeting.modules.client.ClientMeetingRuntimeService.StartScreenShareRequest;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import com.zthz.meeting.modules.admin.recordings.RecordingDownloadService;
import com.zthz.meeting.modules.admin.recordings.RecordingDownloadService.DownloadableRecording;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/client")
public class ClientMeetingController {

    private final ClientMeetingService clientMeetingService;
    private final ClientMeetingRuntimeService clientMeetingRuntimeService;
    private final RecordingDownloadService recordingDownloadService;

    public ClientMeetingController(
            ClientMeetingService clientMeetingService,
            ClientMeetingRuntimeService clientMeetingRuntimeService,
            RecordingDownloadService recordingDownloadService
    ) {
        this.clientMeetingService = clientMeetingService;
        this.clientMeetingRuntimeService = clientMeetingRuntimeService;
        this.recordingDownloadService = recordingDownloadService;
    }

    @PostMapping("/meetings/instant")
    public ApiResponse<MeetingDetailResponse> createInstantMeeting(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CreateMeetingRequest request
    ) {
        return ApiResponse.ok(clientMeetingService.createInstantMeeting(jwt.getSubject(), request));
    }

    @PostMapping("/meetings/scheduled")
    public ApiResponse<MeetingDetailResponse> createScheduledMeeting(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CreateScheduledMeetingRequest request
    ) {
        return ApiResponse.ok(clientMeetingService.createScheduledMeeting(jwt.getSubject(), request));
    }

    @PostMapping("/meetings/join")
    public ApiResponse<JoinMeetingResponse> joinMeeting(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody JoinMeetingRequest request,
            HttpServletRequest httpRequest
    ) {
        return ApiResponse.ok(clientMeetingService.joinMeeting(jwt.getSubject(), request, httpRequest));
    }

    @PostMapping("/meetings/leave")
    public ApiResponse<Void> leaveMeeting(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody LeaveMeetingRequest request
    ) {
        clientMeetingService.leaveMeeting(jwt.getSubject(), request.clientSessionId());
        return ApiResponse.ok();
    }

    @PostMapping("/meetings/reconnect")
    public ApiResponse<JoinMeetingResponse> reconnectMeeting(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ReconnectMeetingRequest request
    ) {
        return ApiResponse.ok(clientMeetingService.reconnectMeeting(jwt.getSubject(), request));
    }

    @GetMapping("/meetings/history")
    public ApiResponse<List<MeetingHistoryResponse>> myMeetingHistory(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.ok(clientMeetingService.myMeetings(jwt.getSubject()));
    }

    @GetMapping("/meetings/{meetingNo}/runtime")
    public ApiResponse<MeetingRuntimeState> meetingRuntime(@PathVariable String meetingNo) {
        return ApiResponse.ok(clientMeetingRuntimeService.getRuntime(meetingNo));
    }

    @PostMapping("/meetings/{meetingNo}/mute")
    public ApiResponse<MeetingRuntimeState> updateMute(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String meetingNo,
            @Valid @RequestBody MuteStateRequest request
    ) {
        return ApiResponse.ok(clientMeetingRuntimeService.updateMute(jwt.getSubject(), meetingNo, request));
    }

    @PostMapping("/meetings/{meetingNo}/network-quality")
    public ApiResponse<MeetingRuntimeState> reportNetworkQuality(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String meetingNo,
            @Valid @RequestBody NetworkQualityRequest request
    ) {
        return ApiResponse.ok(clientMeetingRuntimeService.reportNetworkQuality(jwt.getSubject(), meetingNo, request));
    }

    @PostMapping("/meetings/{meetingNo}/screen-share/start")
    public ApiResponse<ScreenShareResponse> startScreenShare(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String meetingNo,
            @Valid @RequestBody StartScreenShareRequest request
    ) {
        return ApiResponse.ok(clientMeetingRuntimeService.startScreenShare(jwt.getSubject(), meetingNo, request));
    }

    @PostMapping("/meetings/{meetingNo}/screen-share/stop")
    public ApiResponse<MeetingRuntimeState> stopScreenShare(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String meetingNo
    ) {
        return ApiResponse.ok(clientMeetingRuntimeService.stopScreenShare(jwt.getSubject(), meetingNo));
    }

    @GetMapping("/recordings")
    public ApiResponse<List<ClientRecordingResponse>> myRecordings(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.ok(clientMeetingService.myRecordings(jwt.getSubject()));
    }

    @GetMapping("/recordings/{id}/download")
    public ResponseEntity<org.springframework.core.io.Resource> downloadRecording(
            @AuthenticationPrincipal Jwt jwt, @PathVariable Long id) {
        DownloadableRecording download = recordingDownloadService.requireForUser(id, jwt.getSubject(), false);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(download.fileName(), java.nio.charset.StandardCharsets.UTF_8).build().toString())
                .body(download.resource());
    }
}
