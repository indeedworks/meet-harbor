package com.zthz.meeting.modules.admin.meetings;

import com.zthz.meeting.modules.admin.recordings.RecordingRepository;
import com.zthz.meeting.modules.livekit.LiveKitRoomService;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminMeetingService {

    private final MeetingRepository meetingRepository;
    private final MeetingMemberRepository meetingMemberRepository;
    private final MeetingSessionRepository meetingSessionRepository;
    private final RecordingRepository recordingRepository;
    private final LiveKitRoomService liveKitRoomService;

    public AdminMeetingService(
            MeetingRepository meetingRepository,
            MeetingMemberRepository meetingMemberRepository,
            MeetingSessionRepository meetingSessionRepository,
            RecordingRepository recordingRepository,
            LiveKitRoomService liveKitRoomService
    ) {
        this.meetingRepository = meetingRepository;
        this.meetingMemberRepository = meetingMemberRepository;
        this.meetingSessionRepository = meetingSessionRepository;
        this.recordingRepository = recordingRepository;
        this.liveKitRoomService = liveKitRoomService;
    }

    @Transactional(readOnly = true)
    public List<OnlineMeetingResponse> listOnlineMeetings() {
        return meetingRepository.findByStatusOrderByStartedAtDesc("IN_PROGRESS").stream()
                .map(meeting -> new OnlineMeetingResponse(
                        meeting.getTopic(),
                        meeting.getMeetingNo(),
                        meeting.getHostUser().getNickname(),
                        participantCount(meeting),
                        false,
                        recordingRepository.existsByMeetingIdAndStatus(meeting.getId(), "RECORDING"),
                        meeting.getStartedAt(),
                        durationSeconds(meeting.getStartedAt(), OffsetDateTime.now())
                ))
                .toList();
    }

    @Transactional
    public ForceStopMeetingResponse forceStopMeeting(String meetingNo) {
        MeetingEntity meeting = meetingRepository.findByMeetingNo(meetingNo)
                .orElseThrow(() -> new IllegalArgumentException("会议不存在"));
        if (!"IN_PROGRESS".equals(meeting.getStatus())) {
            throw new IllegalArgumentException("会议不在进行中");
        }

        OffsetDateTime now = OffsetDateTime.now();
        List<MeetingSessionEntity> activeSessions = meetingSessionRepository.findAllByMeetingIdAndLeaveAtIsNull(meeting.getId());
        activeSessions.forEach(session -> {
            session.setLeaveAt(now);
            session.setLeaveReason("SERVER_KICK");
        });
        meetingSessionRepository.saveAll(activeSessions);

        meeting.setStatus("ENDED");
        meeting.setEndedAt(now);
        meeting.setUpdatedAt(now);
        meetingRepository.save(meeting);
        liveKitRoomService.deleteRoom(liveKitRoomName(meeting));

        return new ForceStopMeetingResponse(
                meeting.getMeetingNo(),
                meeting.getStatus(),
                activeSessions.size(),
                meeting.getEndedAt()
        );
    }

    @Transactional(readOnly = true)
    public List<HistoryMeetingResponse> listHistoryMeetings() {
        return meetingRepository.findByStatusNotOrderByStartedAtDesc("IN_PROGRESS").stream()
                .map(meeting -> new HistoryMeetingResponse(
                        meeting.getTopic(),
                        meeting.getMeetingNo(),
                        meeting.getHostUser().getNickname(),
                        meeting.getStartedAt(),
                        meeting.getEndedAt(),
                        participantCount(meeting),
                        recordingRepository.existsByMeetingId(meeting.getId()),
                        meeting.getStatus()
                ))
                .toList();
    }

    private int participantCount(MeetingEntity meeting) {
        return Math.max(1, meetingMemberRepository.countByMeetingId(meeting.getId()));
    }

    private int durationSeconds(OffsetDateTime startedAt, OffsetDateTime endedAt) {
        if (startedAt == null || endedAt == null) {
            return 0;
        }
        return Math.max(0, (int) Duration.between(startedAt, endedAt).toSeconds());
    }

    private String liveKitRoomName(MeetingEntity meeting) {
        return "meeting-" + meeting.getMeetingNo();
    }

    public record OnlineMeetingResponse(
            String topic,
            String meetingNo,
            String hostName,
            Integer participantCount,
            Boolean screenSharing,
            Boolean recording,
            OffsetDateTime startedAt,
            Integer durationSeconds
    ) {
    }

    public record HistoryMeetingResponse(
            String topic,
            String meetingNo,
            String creatorName,
            OffsetDateTime startedAt,
            OffsetDateTime endedAt,
            Integer participantCount,
            Boolean hasRecording,
            String status
    ) {
    }

    public record ForceStopMeetingResponse(
            String meetingNo,
            String status,
            Integer closedSessions,
            OffsetDateTime endedAt
    ) {
    }
}
