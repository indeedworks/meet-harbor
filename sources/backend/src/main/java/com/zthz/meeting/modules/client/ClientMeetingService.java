package com.zthz.meeting.modules.client;

import com.zthz.meeting.modules.admin.meetings.MeetingEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingMemberEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingMemberRepository;
import com.zthz.meeting.modules.admin.meetings.MeetingRepository;
import com.zthz.meeting.modules.admin.meetings.MeetingSessionEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingSessionRepository;
import com.zthz.meeting.modules.admin.recordings.RecordingEntity;
import com.zthz.meeting.modules.admin.recordings.RecordingRepository;
import com.zthz.meeting.modules.admin.users.UserEntity;
import com.zthz.meeting.modules.admin.users.UserService;
import com.zthz.meeting.modules.livekit.LiveKitRoomService;
import com.zthz.meeting.modules.livekit.LiveKitTokenService;
import com.zthz.meeting.modules.livekit.LiveKitTokenService.LiveKitConnection;
import jakarta.servlet.http.HttpServletRequest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ClientMeetingService {

    private static final int MAX_ACTIVE_MEETINGS = 5;
    private static final int MAX_PARTICIPANTS_PER_MEETING = 20;

    private final MeetingRepository meetingRepository;
    private final MeetingMemberRepository meetingMemberRepository;
    private final MeetingSessionRepository meetingSessionRepository;
    private final RecordingRepository recordingRepository;
    private final UserService userService;
    private final LiveKitRoomService liveKitRoomService;
    private final LiveKitTokenService liveKitTokenService;
    private final String publicBaseUrl;
    private final SecureRandom secureRandom = new SecureRandom();

    public ClientMeetingService(
            MeetingRepository meetingRepository,
            MeetingMemberRepository meetingMemberRepository,
            MeetingSessionRepository meetingSessionRepository,
            RecordingRepository recordingRepository,
            UserService userService,
            LiveKitRoomService liveKitRoomService,
            LiveKitTokenService liveKitTokenService,
            @Value("${app.public-base-url:http://localhost:8080}") String publicBaseUrl
    ) {
        this.meetingRepository = meetingRepository;
        this.meetingMemberRepository = meetingMemberRepository;
        this.meetingSessionRepository = meetingSessionRepository;
        this.recordingRepository = recordingRepository;
        this.userService = userService;
        this.liveKitRoomService = liveKitRoomService;
        this.liveKitTokenService = liveKitTokenService;
        this.publicBaseUrl = publicBaseUrl;
    }

    @Transactional
    public MeetingDetailResponse createInstantMeeting(String account, CreateMeetingRequest request) {
        if (meetingRepository.countByStatus("IN_PROGRESS") >= MAX_ACTIVE_MEETINGS) {
            throw new IllegalArgumentException("当前在线会议数已达到上限");
        }
        UserEntity host = userService.requireEnabledUserByAccount(account);
        OffsetDateTime now = OffsetDateTime.now();
        MeetingEntity meeting = newMeeting(request.topic(), "INSTANT", host, "IN_PROGRESS", now, now, null);
        MeetingEntity saved = meetingRepository.save(meeting);
        ensureMember(saved, host, "HOST", now);
        return MeetingDetailResponse.from(saved, invitationLink(saved), null);
    }

    @Transactional
    public MeetingDetailResponse createScheduledMeeting(String account, CreateScheduledMeetingRequest request) {
        UserEntity host = userService.requireEnabledUserByAccount(account);
        OffsetDateTime now = OffsetDateTime.now();
        MeetingEntity meeting = newMeeting(
                request.topic(),
                "SCHEDULED",
                host,
                "SCHEDULED",
                request.scheduledStartAt(),
                null,
                null
        );
        meeting.setCreatedAt(now);
        meeting.setUpdatedAt(now);
        MeetingEntity saved = meetingRepository.save(meeting);
        ensureMember(saved, host, "HOST", null);
        return MeetingDetailResponse.from(saved, invitationLink(saved), null);
    }

    @Transactional
    public JoinMeetingResponse joinMeeting(String account, JoinMeetingRequest request, HttpServletRequest httpRequest) {
        UserEntity user = userService.requireEnabledUserByAccount(account);
        MeetingEntity meeting = meetingRepository.findByMeetingNo(request.meetingNo())
                .orElseThrow(() -> new IllegalArgumentException("会议不存在"));
        if ("ENDED".equals(meeting.getStatus()) || "CANCELLED".equals(meeting.getStatus())) {
            throw new IllegalArgumentException("会议已结束");
        }
        if ("SCHEDULED".equals(meeting.getStatus()) || "WAITING".equals(meeting.getStatus())) {
            meeting.setStatus("IN_PROGRESS");
            meeting.setStartedAt(OffsetDateTime.now());
            meeting.setUpdatedAt(OffsetDateTime.now());
            meetingRepository.save(meeting);
        }

        long activeParticipants = meetingSessionRepository.countByMeetingIdAndLeaveAtIsNull(meeting.getId());
        if (activeParticipants >= MAX_PARTICIPANTS_PER_MEETING) {
            throw new IllegalArgumentException("会议人数已达到上限");
        }

        String roomName = liveKitRoomName(meeting);
        liveKitRoomService.ensureRoom(roomName);
        ensureMember(meeting, user, meeting.getHostUser().getId().equals(user.getId()) ? "HOST" : "PARTICIPANT", OffsetDateTime.now());
        String clientSessionId = UUID.randomUUID().toString();
        MeetingSessionEntity session = new MeetingSessionEntity();
        session.setMeeting(meeting);
        session.setUser(user);
        session.setClientSessionId(clientSessionId);
        session.setJoinAt(OffsetDateTime.now());
        session.setReconnectCount(0);
        session.setClientIp(clientIp(httpRequest));
        session.setUserAgent(httpRequest.getHeader("User-Agent"));
        session.setCreatedAt(OffsetDateTime.now());
        meetingSessionRepository.save(session);

        LiveKitConnection liveKit = liveKitTokenService.createParticipantToken(
                roomName,
                user.getAccount(),
                user.getNickname()
        );
        return new JoinMeetingResponse(
                MeetingDetailResponse.from(meeting, invitationLink(meeting), clientSessionId),
                liveKit
        );
    }

    @Transactional
    public void leaveMeeting(String account, String clientSessionId) {
        MeetingSessionEntity session = meetingSessionRepository.findByClientSessionIdAndLeaveAtIsNull(clientSessionId)
                .orElseThrow(() -> new IllegalArgumentException("会议会话不存在或已离会"));
        if (!account.equals(session.getUser().getAccount())) {
            throw new IllegalArgumentException("不能结束其他用户的会议会话");
        }
        OffsetDateTime now = OffsetDateTime.now();
        session.setLeaveAt(now);
        session.setLeaveReason("NORMAL");
        meetingSessionRepository.save(session);

        MeetingEntity meeting = session.getMeeting();
        if (meetingSessionRepository.countByMeetingIdAndLeaveAtIsNull(meeting.getId()) == 0 && "IN_PROGRESS".equals(meeting.getStatus())) {
            meeting.setStatus("ENDED");
            meeting.setEndedAt(now);
            meeting.setUpdatedAt(now);
            meetingRepository.save(meeting);
            liveKitRoomService.deleteRoom(liveKitRoomName(meeting));
        }
    }

    @Transactional
    public JoinMeetingResponse reconnectMeeting(String account, ReconnectMeetingRequest request) {
        MeetingSessionEntity session = meetingSessionRepository.findByClientSessionIdAndLeaveAtIsNull(request.clientSessionId())
                .orElseThrow(() -> new IllegalArgumentException("会议会话不存在或已离会"));
        if (!account.equals(session.getUser().getAccount())) {
            throw new IllegalArgumentException("不能重连其他用户的会议会话");
        }
        MeetingEntity meeting = session.getMeeting();
        if (!"IN_PROGRESS".equals(meeting.getStatus())) {
            throw new IllegalArgumentException("会议不在进行中");
        }
        session.setReconnectCount(session.getReconnectCount() + 1);
        meetingSessionRepository.save(session);
        String roomName = liveKitRoomName(meeting);
        liveKitRoomService.ensureRoom(roomName);
        LiveKitConnection liveKit = liveKitTokenService.createParticipantToken(
                roomName,
                session.getUser().getAccount(),
                session.getUser().getNickname()
        );
        return new JoinMeetingResponse(
                MeetingDetailResponse.from(meeting, invitationLink(meeting), session.getClientSessionId()),
                liveKit
        );
    }

    @Transactional(readOnly = true)
    public List<MeetingHistoryResponse> myMeetings(String account) {
        UserEntity user = userService.requireEnabledUserByAccount(account);
        return meetingMemberRepository.findAll().stream()
                .filter(member -> member.getUser().getId().equals(user.getId()))
                .map(member -> MeetingHistoryResponse.from(member.getMeeting()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ClientRecordingResponse> myRecordings(String account) {
        UserEntity user = userService.requireEnabledUserByAccount(account);
        List<Long> meetingIds = meetingMemberRepository.findAll().stream()
                .filter(member -> member.getUser().getId().equals(user.getId()))
                .map(member -> member.getMeeting().getId())
                .toList();
        return recordingRepository.findAllByOrderByCreatedAtDesc().stream()
                .filter(recording -> meetingIds.contains(recording.getMeeting().getId()))
                .map(ClientRecordingResponse::from)
                .toList();
    }

    private MeetingEntity newMeeting(
            String topic,
            String type,
            UserEntity host,
            String status,
            OffsetDateTime scheduledStartAt,
            OffsetDateTime startedAt,
            OffsetDateTime endedAt
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        MeetingEntity meeting = new MeetingEntity();
        meeting.setMeetingNo(nextMeetingNo());
        meeting.setPasswordHash(null);
        meeting.setTopic(topic);
        meeting.setMeetingType(type);
        meeting.setHostUser(host);
        meeting.setStatus(status);
        meeting.setScheduledStartAt(scheduledStartAt);
        meeting.setStartedAt(startedAt);
        meeting.setEndedAt(endedAt);
        meeting.setCreatedAt(now);
        meeting.setUpdatedAt(now);
        return meeting;
    }

    private void ensureMember(MeetingEntity meeting, UserEntity user, String role, OffsetDateTime joinedAt) {
        meetingMemberRepository.findByMeetingIdAndUserId(meeting.getId(), user.getId()).ifPresentOrElse(member -> {
            if (joinedAt != null && member.getFirstJoinedAt() == null) {
                member.setFirstJoinedAt(joinedAt);
                member.setUpdatedAt(OffsetDateTime.now());
                meetingMemberRepository.save(member);
            }
        }, () -> {
            OffsetDateTime now = OffsetDateTime.now();
            MeetingMemberEntity member = new MeetingMemberEntity();
            member.setMeeting(meeting);
            member.setUser(user);
            member.setMeetingRole(role);
            member.setFirstJoinedAt(joinedAt);
            member.setTotalDurationSeconds(0);
            member.setCreatedAt(now);
            member.setUpdatedAt(now);
            meetingMemberRepository.save(member);
        });
    }

    private String nextMeetingNo() {
        String meetingNo;
        do {
            meetingNo = String.valueOf(10000000 + secureRandom.nextInt(90000000));
        } while (meetingRepository.existsByMeetingNo(meetingNo));
        return meetingNo;
    }

    private String invitationLink(MeetingEntity meeting) {
        return publicBaseUrl + "/join?meetingNo=" + meeting.getMeetingNo();
    }

    private String liveKitRoomName(MeetingEntity meeting) {
        return "meeting-" + meeting.getMeetingNo();
    }

    private String clientIp(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return forwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    public record CreateMeetingRequest(String topic) {
    }

    public record CreateScheduledMeetingRequest(String topic, OffsetDateTime scheduledStartAt) {
    }

    public record JoinMeetingRequest(String meetingNo) {
    }

    public record LeaveMeetingRequest(String clientSessionId) {
    }

    public record ReconnectMeetingRequest(String clientSessionId) {
    }

    public record MeetingDetailResponse(
            Long id,
            String topic,
            String meetingNo,
            String invitationLink,
            String status,
            String hostName,
            OffsetDateTime scheduledStartAt,
            OffsetDateTime startedAt,
            String clientSessionId
    ) {
        static MeetingDetailResponse from(MeetingEntity meeting, String invitationLink, String clientSessionId) {
            return new MeetingDetailResponse(
                    meeting.getId(),
                    meeting.getTopic(),
                    meeting.getMeetingNo(),
                    invitationLink,
                    meeting.getStatus(),
                    meeting.getHostUser().getNickname(),
                    meeting.getScheduledStartAt(),
                    meeting.getStartedAt(),
                    clientSessionId
            );
        }
    }

    public record JoinMeetingResponse(MeetingDetailResponse meeting, LiveKitConnection liveKit) {
    }

    public record MeetingHistoryResponse(
            Long id,
            String topic,
            String meetingNo,
            String status,
            OffsetDateTime scheduledStartAt,
            OffsetDateTime startedAt,
            OffsetDateTime endedAt,
            Integer durationSeconds
    ) {
        static MeetingHistoryResponse from(MeetingEntity meeting) {
            int duration = 0;
            if (meeting.getStartedAt() != null && meeting.getEndedAt() != null) {
                duration = Math.max(0, (int) Duration.between(meeting.getStartedAt(), meeting.getEndedAt()).toSeconds());
            }
            return new MeetingHistoryResponse(
                    meeting.getId(),
                    meeting.getTopic(),
                    meeting.getMeetingNo(),
                    meeting.getStatus(),
                    meeting.getScheduledStartAt(),
                    meeting.getStartedAt(),
                    meeting.getEndedAt(),
                    duration
            );
        }
    }

    public record ClientRecordingResponse(
            Long id,
            String meetingTopic,
            String meetingNo,
            String status,
            String fileName,
            Long fileSizeBytes,
            OffsetDateTime createdAt,
            OffsetDateTime expiredAt
    ) {
        static ClientRecordingResponse from(RecordingEntity recording) {
            return new ClientRecordingResponse(
                    recording.getId(),
                    recording.getMeeting().getTopic(),
                    recording.getMeeting().getMeetingNo(),
                    recording.getStatus(),
                    recording.getFileName(),
                    recording.getFileSizeBytes(),
                    recording.getCreatedAt(),
                    recording.getExpiredAt()
            );
        }
    }
}
