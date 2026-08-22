package com.zthz.meeting.modules.livekit;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zthz.meeting.common.ApiResponse;
import com.zthz.meeting.modules.admin.meetings.MeetingEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingRepository;
import com.zthz.meeting.modules.client.MeetingLifecycleService;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import org.springframework.http.MediaType;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/livekit")
public class LiveKitWebhookController {

    private static final ZoneId SYSTEM_ZONE = ZoneId.systemDefault();

    private final LiveKitTokenService liveKitTokenService;
    private final MeetingRepository meetingRepository;
    private final MeetingLifecycleService meetingLifecycleService;
    private final ObjectMapper objectMapper;

    public LiveKitWebhookController(
            LiveKitTokenService liveKitTokenService,
            MeetingRepository meetingRepository,
            MeetingLifecycleService meetingLifecycleService,
            ObjectMapper objectMapper
    ) {
        this.liveKitTokenService = liveKitTokenService;
        this.meetingRepository = meetingRepository;
        this.meetingLifecycleService = meetingLifecycleService;
        this.objectMapper = objectMapper;
    }

    @Transactional
    @PostMapping(
            value = "/webhook",
            consumes = {"application/webhook+json", MediaType.APPLICATION_JSON_VALUE}
    )
    public ApiResponse<Void> receiveWebhook(
            @RequestHeader("Authorization") String authorization,
            @RequestBody String rawBody
    ) throws Exception {
        liveKitTokenService.verifyWebhook(authorization, rawBody);
        JsonNode event = objectMapper.readTree(rawBody);
        applyEvent(event);
        return ApiResponse.ok();
    }

    private void applyEvent(JsonNode event) {
        String eventType = event.path("event").asText("");
        String roomName = roomName(event);
        if (roomName == null || roomName.isBlank()) {
            return;
        }
        String meetingNo = meetingNoFromRoom(roomName);
        meetingRepository.findByMeetingNo(meetingNo).ifPresent(meeting -> {
            switch (eventType) {
                case "room_started" -> markMeetingStarted(meeting, event);
                case "room_finished" -> markMeetingFinished(meeting, event);
                case "participant_left", "participant_connection_aborted" -> markParticipantLeft(meeting, event);
                default -> {
                }
            }
        });
    }

    private void markMeetingStarted(MeetingEntity meeting, JsonNode event) {
        if (!"IN_PROGRESS".equals(meeting.getStatus())) {
            meeting.setStatus("IN_PROGRESS");
            meeting.setStartedAt(eventTime(event));
            meeting.setUpdatedAt(OffsetDateTime.now());
            meetingRepository.save(meeting);
        }
    }

    private void markMeetingFinished(MeetingEntity meeting, JsonNode event) {
        if ("IN_PROGRESS".equals(meeting.getStatus())) {
            meeting.setStatus("ENDED");
            meeting.setEndedAt(eventTime(event));
            meeting.setUpdatedAt(OffsetDateTime.now());
            meetingRepository.save(meeting);
        }
    }

    private void markParticipantLeft(MeetingEntity meeting, JsonNode event) {
        String identity = event.path("participant").path("identity").asText("");
        if (identity.isBlank()) {
            return;
        }
        meetingLifecycleService.closeLatestActiveSession(
                meeting.getMeetingNo(),
                identity,
                "NETWORK_DISCONNECT",
                eventTime(event)
        );
    }

    private String roomName(JsonNode event) {
        String roomName = event.path("room").path("name").asText("");
        if (!roomName.isBlank()) {
            return roomName;
        }
        return event.path("roomName").asText(null);
    }

    private String meetingNoFromRoom(String roomName) {
        if (roomName.startsWith("meeting-")) {
            return roomName.substring("meeting-".length());
        }
        return roomName;
    }

    private OffsetDateTime eventTime(JsonNode event) {
        long createdAt = event.path("createdAt").asLong(0);
        if (createdAt <= 0) {
            return OffsetDateTime.now();
        }
        return OffsetDateTime.ofInstant(Instant.ofEpochSecond(createdAt), SYSTEM_ZONE);
    }
}
