package com.zthz.meeting.modules.client;

import com.zthz.meeting.modules.admin.meetings.MeetingEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingRepository;
import com.zthz.meeting.modules.admin.meetings.MeetingSessionEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingSessionRepository;
import com.zthz.meeting.modules.livekit.LiveKitRoomService;
import com.zthz.meeting.modules.livekit.LiveKitEgressService;
import java.time.OffsetDateTime;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MeetingLifecycleService {

    private static final long RECONNECT_GRACE_SECONDS = 15;

    private final MeetingRepository meetingRepository;
    private final MeetingSessionRepository meetingSessionRepository;
    private final LiveKitRoomService liveKitRoomService;
    private final LiveKitEgressService liveKitEgressService;
    private final Map<String, Instant> reconnectingParticipants = new ConcurrentHashMap<>();

    public MeetingLifecycleService(
            MeetingRepository meetingRepository,
            MeetingSessionRepository meetingSessionRepository,
            LiveKitRoomService liveKitRoomService,
            LiveKitEgressService liveKitEgressService
    ) {
        this.meetingRepository = meetingRepository;
        this.meetingSessionRepository = meetingSessionRepository;
        this.liveKitRoomService = liveKitRoomService;
        this.liveKitEgressService = liveKitEgressService;
    }

    @Transactional
    public void closeLatestActiveSession(String meetingNo, String account, String leaveReason, OffsetDateTime leaveAt) {
        if (meetingNo == null || meetingNo.isBlank() || account == null || account.isBlank()) {
            return;
        }
        if (isInReconnectGrace(meetingNo, account)) {
            return;
        }
        meetingRepository.findByMeetingNo(meetingNo).ifPresent(meeting -> {
            meetingSessionRepository
                    .findFirstByMeetingIdAndUserAccountAndLeaveAtIsNullOrderByJoinAtDesc(meeting.getId(), account)
                    .ifPresent(session -> closeSession(session, leaveReason, leaveAt));
            finishMeetingIfEmpty(meeting, leaveAt);
        });
    }

    public void markReconnecting(String meetingNo, String account) {
        if (meetingNo == null || meetingNo.isBlank() || account == null || account.isBlank()) {
            return;
        }
        reconnectingParticipants.put(reconnectKey(meetingNo, account), Instant.now().plusSeconds(RECONNECT_GRACE_SECONDS));
    }

    @Transactional
    public void finishMeetingIfEmpty(String meetingNo, OffsetDateTime endedAt) {
        if (meetingNo == null || meetingNo.isBlank()) {
            return;
        }
        meetingRepository.findByMeetingNo(meetingNo)
                .ifPresent(meeting -> finishMeetingIfEmpty(meeting, endedAt));
    }

    private void closeSession(MeetingSessionEntity session, String leaveReason, OffsetDateTime leaveAt) {
        if (session.getLeaveAt() != null) {
            return;
        }
        session.setLeaveAt(leaveAt == null ? OffsetDateTime.now() : leaveAt);
        session.setLeaveReason(leaveReason == null || leaveReason.isBlank() ? "UNKNOWN" : leaveReason);
        meetingSessionRepository.save(session);
    }

    private void finishMeetingIfEmpty(MeetingEntity meeting, OffsetDateTime endedAt) {
        if (!"IN_PROGRESS".equals(meeting.getStatus())) {
            return;
        }
        if (meetingSessionRepository.countByMeetingIdAndLeaveAtIsNull(meeting.getId()) > 0) {
            return;
        }
        OffsetDateTime finishAt = endedAt == null ? OffsetDateTime.now() : endedAt;
        meeting.setStatus("ENDED");
        meeting.setEndedAt(finishAt);
        meeting.setUpdatedAt(OffsetDateTime.now());
        meetingRepository.save(meeting);
        liveKitEgressService.stopIfActive(meeting);
        liveKitRoomService.deleteRoom(liveKitRoomName(meeting));
    }

    private String liveKitRoomName(MeetingEntity meeting) {
        return "meeting-" + meeting.getMeetingNo();
    }

    private boolean isInReconnectGrace(String meetingNo, String account) {
        String key = reconnectKey(meetingNo, account);
        Instant expiresAt = reconnectingParticipants.get(key);
        if (expiresAt == null) {
            return false;
        }
        if (Instant.now().isBefore(expiresAt)) {
            return true;
        }
        reconnectingParticipants.remove(key);
        return false;
    }

    private String reconnectKey(String meetingNo, String account) {
        return meetingNo + ":" + account;
    }
}
