package com.zthz.meeting.modules.livekit;

import java.net.URI;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

@Service
public class LiveKitRoomService {

    private static final Logger log = LoggerFactory.getLogger(LiveKitRoomService.class);
    private static final int MAX_PARTICIPANTS_PER_MEETING = 20;

    private final LiveKitTokenService liveKitTokenService;
    private final RestClient restClient;
    private final int emptyTimeoutSeconds;
    private final int departureTimeoutSeconds;

    public LiveKitRoomService(
            LiveKitTokenService liveKitTokenService,
            @Value("${app.livekit.internal-url}") String liveKitUrl,
            @Value("${app.livekit.room-empty-timeout-seconds}") int emptyTimeoutSeconds,
            @Value("${app.livekit.room-departure-timeout-seconds}") int departureTimeoutSeconds
    ) {
        this.liveKitTokenService = liveKitTokenService;
        this.restClient = RestClient.builder()
                .baseUrl(toHttpUrl(liveKitUrl))
                .build();
        this.emptyTimeoutSeconds = emptyTimeoutSeconds;
        this.departureTimeoutSeconds = departureTimeoutSeconds;
    }

    public void ensureRoom(String roomName) {
        try {
            post("/twirp/livekit.RoomService/CreateRoom", Map.of(
                    "name", roomName,
                    "empty_timeout", emptyTimeoutSeconds,
                    "departure_timeout", departureTimeoutSeconds,
                    "max_participants", MAX_PARTICIPANTS_PER_MEETING
            ), Map.of("roomCreate", true));
        } catch (HttpClientErrorException.Conflict exception) {
            // The room already exists, which is fine for rejoin/reconnect flows.
        } catch (HttpClientErrorException.BadRequest exception) {
            if (!exception.getResponseBodyAsString().contains("already exists")) {
                throw exception;
            }
        }
    }

    public void deleteRoom(String roomName) {
        try {
            post("/twirp/livekit.RoomService/DeleteRoom", Map.of("room", roomName), Map.of("roomCreate", true));
        } catch (HttpClientErrorException.NotFound ignored) {
            // If LiveKit has already closed the empty room, the business state can still end normally.
        } catch (RuntimeException exception) {
            log.warn("Failed to delete LiveKit room {}: {}", roomName, exception.getMessage());
        }
    }

    private String post(String path, Map<String, ?> body, Map<String, Object> grant) {
        String token = liveKitTokenService.createRoomServiceToken(grant);
        return restClient.post()
                .uri(path)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(String.class);
    }

    private String toHttpUrl(String liveKitUrl) {
        URI uri = URI.create(liveKitUrl);
        String scheme = switch (uri.getScheme()) {
            case "ws" -> "http";
            case "wss" -> "https";
            default -> uri.getScheme();
        };
        return URI.create(scheme + "://" + uri.getAuthority()).toString();
    }
}
