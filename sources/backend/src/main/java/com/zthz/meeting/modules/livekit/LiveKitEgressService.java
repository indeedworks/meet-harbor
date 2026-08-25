package com.zthz.meeting.modules.livekit;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zthz.meeting.modules.admin.meetings.MeetingEntity;
import com.zthz.meeting.modules.admin.recordings.RecordingEntity;
import com.zthz.meeting.modules.admin.recordings.RecordingRepository;
import java.net.URI;
import java.nio.file.Path;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestClient;

@Service
public class LiveKitEgressService {

    private static final Logger log = LoggerFactory.getLogger(LiveKitEgressService.class);
    private static final List<String> ACTIVE_STATUSES = List.of("RECORDING", "PROCESSING");

    private final LiveKitTokenService tokenService;
    private final RecordingRepository recordingRepository;
    private final ObjectMapper objectMapper;
    private final RestClient restClient;
    private final Path storageRoot;
    private final int retentionDays;
    private final boolean enabled;

    public LiveKitEgressService(
            LiveKitTokenService tokenService,
            RecordingRepository recordingRepository,
            ObjectMapper objectMapper,
            @Value("${app.livekit.internal-url}") String liveKitUrl,
            @Value("${app.recording.storage-path:/data/recordings}") String storagePath,
            @Value("${app.recording.retention-days:7}") int retentionDays,
            @Value("${app.recording.auto-enabled:true}") boolean enabled
    ) {
        this.tokenService = tokenService;
        this.recordingRepository = recordingRepository;
        this.objectMapper = objectMapper;
        this.restClient = RestClient.builder().baseUrl(toHttpUrl(liveKitUrl)).build();
        this.storageRoot = Path.of(storagePath).toAbsolutePath().normalize();
        this.retentionDays = retentionDays;
        this.enabled = enabled;
    }

    @Transactional
    public void startIfNeeded(MeetingEntity meeting) {
        if (!enabled || recordingRepository.findFirstByMeetingIdAndStatusInOrderByCreatedAtDesc(
                meeting.getId(), ACTIVE_STATUSES).isPresent()) {
            return;
        }
        OffsetDateTime now = OffsetDateTime.now();
        String fileName = meeting.getMeetingNo() + "-" + UUID.randomUUID() + ".mp4";
        Path output = storageRoot.resolve(meeting.getMeetingNo()).resolve(fileName).normalize();
        RecordingEntity recording = new RecordingEntity();
        recording.setMeeting(meeting);
        recording.setStartedBy(meeting.getHostUser());
        recording.setStatus("NOT_STARTED");
        recording.setFilePath(output.toString());
        recording.setFileName(fileName);
        recording.setFileSizeBytes(0L);
        recording.setDurationSeconds(0);
        recording.setCreatedAt(now);
        recording.setUpdatedAt(now);
        recordingRepository.save(recording);
        try {
            JsonNode result = post("/twirp/livekit.Egress/StartRoomCompositeEgress", Map.of(
                    "room_name", roomName(meeting),
                    "layout", "grid",
                    "file_outputs", List.of(Map.of("filepath", output.toString()))
            ));
            recording.setEgressId(result.path("egress_id").asText());
            recording.setStatus("RECORDING");
            recording.setStartedAt(now);
        } catch (RuntimeException exception) {
            recording.setStatus("FAILED");
            recording.setErrorMessage(exception.getMessage());
            log.error("Failed to start recording for meeting {}", meeting.getMeetingNo(), exception);
        }
        recording.setUpdatedAt(OffsetDateTime.now());
        recordingRepository.save(recording);
    }

    @Transactional
    public void stopIfActive(MeetingEntity meeting) {
        recordingRepository.findFirstByMeetingIdAndStatusInOrderByCreatedAtDesc(meeting.getId(), ACTIVE_STATUSES)
                .ifPresent(recording -> {
                    recording.setStatus("PROCESSING");
                    recording.setStoppedAt(OffsetDateTime.now());
                    recording.setUpdatedAt(OffsetDateTime.now());
                    recordingRepository.save(recording);
                    try {
                        post("/twirp/livekit.Egress/StopEgress", Map.of("egress_id", recording.getEgressId()));
                    } catch (RuntimeException exception) {
                        recording.setStatus("FAILED");
                        recording.setErrorMessage(exception.getMessage());
                        recording.setUpdatedAt(OffsetDateTime.now());
                        recordingRepository.save(recording);
                        log.error("Failed to stop egress {}", recording.getEgressId(), exception);
                    }
                });
    }

    @Transactional
    public void applyWebhook(JsonNode event) {
        JsonNode info = event.path("egressInfo");
        if (info.isMissingNode()) info = event.path("egress_info");
        String egressId = info.path("egressId").asText(info.path("egress_id").asText(""));
        if (egressId.isBlank()) return;
        JsonNode finalInfo = info;
        recordingRepository.findByEgressId(egressId).ifPresent(recording -> updateFromEgress(recording, finalInfo));
    }

    private void updateFromEgress(RecordingEntity recording, JsonNode info) {
        String status = info.path("status").asText("");
        OffsetDateTime now = OffsetDateTime.now();
        if (status.contains("COMPLETE") || status.equals("3")) {
            JsonNode file = firstFileResult(info);
            recording.setStatus("COMPLETED");
            recording.setCompletedAt(now);
            recording.setExpiredAt(now.plusDays(retentionDays));
            if (!file.isMissingNode()) {
                recording.setFileSizeBytes(file.path("size").asLong(0));
                long durationNanos = file.path("duration").asLong(0);
                recording.setDurationSeconds((int) Duration.ofNanos(durationNanos).toSeconds());
            }
        } else if (status.contains("FAILED") || status.contains("ABORTED") || status.contains("LIMIT_REACHED")
                || status.equals("4") || status.equals("5") || status.equals("6")) {
            recording.setStatus("FAILED");
            recording.setErrorMessage(info.path("error").asText("LiveKit Egress failed"));
        } else if (status.contains("ENDING") || status.equals("2")) {
            recording.setStatus("PROCESSING");
        } else {
            recording.setStatus("RECORDING");
        }
        recording.setUpdatedAt(now);
        recordingRepository.save(recording);
    }

    private JsonNode firstFileResult(JsonNode info) {
        JsonNode results = info.path("fileResults");
        if (!results.isArray()) results = info.path("file_results");
        return results.isArray() && !results.isEmpty() ? results.get(0) : objectMapper.createObjectNode().missingNode();
    }

    private JsonNode post(String path, Map<String, ?> body) {
        String token = tokenService.createRoomServiceToken(Map.of("roomRecord", true));
        String response = restClient.post().uri(path)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).body(body).retrieve().body(String.class);
        try {
            return objectMapper.readTree(response);
        } catch (Exception exception) {
            throw new IllegalStateException("Invalid LiveKit Egress response", exception);
        }
    }

    private String roomName(MeetingEntity meeting) { return "meeting-" + meeting.getMeetingNo(); }

    private String toHttpUrl(String liveKitUrl) {
        URI uri = URI.create(liveKitUrl);
        String scheme = "wss".equals(uri.getScheme()) ? "https" : "ws".equals(uri.getScheme()) ? "http" : uri.getScheme();
        return URI.create(scheme + "://" + uri.getAuthority()).toString();
    }
}
