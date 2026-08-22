package com.zthz.meeting.modules.signaling;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zthz.meeting.modules.client.MeetingLifecycleService;
import java.io.IOException;
import java.net.URI;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.ArrayList;
import java.util.List;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import org.springframework.web.util.UriComponentsBuilder;

@Component
public class SignalingWebSocketHandler extends TextWebSocketHandler {

    private static final String ATTR_MEETING_NO = "meetingNo";
    private static final String ATTR_ACCOUNT = "account";
    private static final String ATTR_NICKNAME = "nickname";

    private final JwtDecoder jwtDecoder;
    private final ObjectMapper objectMapper;
    private final MeetingLifecycleService meetingLifecycleService;
    private final Map<String, Set<WebSocketSession>> rooms = new ConcurrentHashMap<>();

    public SignalingWebSocketHandler(
            JwtDecoder jwtDecoder,
            ObjectMapper objectMapper,
            MeetingLifecycleService meetingLifecycleService
    ) {
        this.jwtDecoder = jwtDecoder;
        this.objectMapper = objectMapper;
        this.meetingLifecycleService = meetingLifecycleService;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        Query query = parseQuery(session.getUri());
        if (query.token() == null || query.meetingNo() == null) {
            session.close(CloseStatus.BAD_DATA.withReason("missing token or meetingNo"));
            return;
        }

        Jwt jwt = jwtDecoder.decode(query.token());
        session.getAttributes().put(ATTR_MEETING_NO, query.meetingNo());
        session.getAttributes().put(ATTR_ACCOUNT, jwt.getSubject());
        session.getAttributes().put(ATTR_NICKNAME, jwt.getClaimAsString("nickname"));
        rooms.computeIfAbsent(query.meetingNo(), ignored -> ConcurrentHashMap.newKeySet()).add(session);

        send(session, Map.of(
                "type", "server.connected",
                "meetingNo", query.meetingNo(),
                "account", jwt.getSubject(),
                "serverTime", OffsetDateTime.now().toString()
        ));
        broadcast(session, Map.of(
                "type", "server.member_joined",
                "meetingNo", query.meetingNo(),
                "account", jwt.getSubject(),
                "nickname", String.valueOf(jwt.getClaimAsString("nickname")),
                "serverTime", OffsetDateTime.now().toString()
        ));
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        Map<?, ?> payload = objectMapper.readValue(message.getPayload(), Map.class);
        Object type = payload.get("type") == null ? "client.event" : payload.get("type");
        Map<String, Object> event = new LinkedHashMap<>();
        event.put("type", type);
        event.put("meetingNo", session.getAttributes().get(ATTR_MEETING_NO));
        event.put("account", session.getAttributes().get(ATTR_ACCOUNT));
        event.put("nickname", session.getAttributes().get(ATTR_NICKNAME));
        event.put("payload", payload);
        event.put("serverTime", OffsetDateTime.now().toString());
        if ("client.reconnecting".equals(type)) {
            meetingLifecycleService.markReconnecting(
                    (String) session.getAttributes().get(ATTR_MEETING_NO),
                    (String) session.getAttributes().get(ATTR_ACCOUNT)
            );
        }
        broadcast(session, event);
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        String meetingNo = (String) session.getAttributes().get(ATTR_MEETING_NO);
        if (meetingNo == null) {
            return;
        }
        Set<WebSocketSession> sessions = rooms.get(meetingNo);
        if (sessions != null) {
            sessions.remove(session);
            if (sessions.isEmpty()) {
                rooms.remove(meetingNo);
            }
        }
        Map<String, Object> event = new LinkedHashMap<>();
        event.put("type", "server.member_left");
        event.put("meetingNo", meetingNo);
        event.put("account", session.getAttributes().get(ATTR_ACCOUNT));
        event.put("serverTime", OffsetDateTime.now().toString());
        broadcast(session, event);
        meetingLifecycleService.closeLatestActiveSession(
                meetingNo,
                (String) session.getAttributes().get(ATTR_ACCOUNT),
                "NETWORK_DISCONNECT",
                OffsetDateTime.now()
        );
    }

    private void broadcast(WebSocketSession sender, Map<String, ?> event) throws IOException {
        String meetingNo = (String) sender.getAttributes().get(ATTR_MEETING_NO);
        if (meetingNo == null) {
            return;
        }
        String json = objectMapper.writeValueAsString(event);
        Set<WebSocketSession> sessions = rooms.get(meetingNo);
        if (sessions == null) {
            return;
        }
        List<WebSocketSession> closedSessions = new ArrayList<>();
        for (WebSocketSession session : sessions) {
            if (session.isOpen() && !session.getId().equals(sender.getId())) {
                try {
                    session.sendMessage(new TextMessage(json));
                } catch (IOException exception) {
                    closedSessions.add(session);
                }
            } else if (!session.isOpen()) {
                closedSessions.add(session);
            }
        }
        sessions.removeAll(closedSessions);
    }

    private void send(WebSocketSession session, Map<String, ?> event) throws IOException {
        if (session.isOpen()) {
            session.sendMessage(new TextMessage(objectMapper.writeValueAsString(event)));
        }
    }

    private Query parseQuery(URI uri) {
        Map<String, String> params = UriComponentsBuilder.fromUri(uri).build().getQueryParams().toSingleValueMap();
        return new Query(params.get("token"), params.get("meetingNo"));
    }

    private record Query(String token, String meetingNo) {
    }
}
