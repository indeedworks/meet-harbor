package com.zthz.meeting.modules.client;

import com.zthz.meeting.modules.admin.meetings.MeetingEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingRepository;
import com.zthz.meeting.modules.admin.users.UserEntity;
import com.zthz.meeting.modules.admin.users.UserService;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

@Service
public class ClientMeetingRuntimeService {

    private final MeetingRepository meetingRepository;
    private final UserService userService;
    private final Map<String, MeetingRuntimeState> runtimeStates = new ConcurrentHashMap<>();

    public ClientMeetingRuntimeService(MeetingRepository meetingRepository, UserService userService) {
        this.meetingRepository = meetingRepository;
        this.userService = userService;
    }

    public MeetingRuntimeState getRuntime(String meetingNo) {
        requireMeeting(meetingNo);
        return runtimeStates.computeIfAbsent(meetingNo, MeetingRuntimeState::new);
    }

    public MeetingRuntimeState updateMute(String account, String meetingNo, MuteStateRequest request) {
        UserEntity user = userService.requireEnabledUserByAccount(account);
        MeetingRuntimeState state = getRuntime(meetingNo);
        ParticipantRuntimeState participant = state.participant(user.getAccount(), user.getNickname());
        participant.muted = request.muted();
        participant.updatedAt = OffsetDateTime.now();
        return state;
    }

    public MeetingRuntimeState reportNetworkQuality(String account, String meetingNo, NetworkQualityRequest request) {
        UserEntity user = userService.requireEnabledUserByAccount(account);
        MeetingRuntimeState state = getRuntime(meetingNo);
        ParticipantRuntimeState participant = state.participant(user.getAccount(), user.getNickname());
        participant.networkQuality = request.quality();
        participant.latencyMs = request.latencyMs();
        participant.packetLossPercent = request.packetLossPercent();
        participant.audioBitrateKbps = request.audioBitrateKbps();
        participant.screenShareBitrateKbps = request.screenShareBitrateKbps();
        participant.updatedAt = OffsetDateTime.now();
        return state;
    }

    public ScreenShareResponse startScreenShare(String account, String meetingNo, StartScreenShareRequest request) {
        UserEntity user = userService.requireEnabledUserByAccount(account);
        MeetingRuntimeState state = getRuntime(meetingNo);
        ScreenShareState previous = state.screenShare;
        ScreenShareState current = new ScreenShareState(
                true,
                user.getAccount(),
                user.getNickname(),
                request.scope(),
                request.sourceName(),
                OffsetDateTime.now()
        );
        state.screenShare = current;
        state.updatedAt = OffsetDateTime.now();
        String replacedAccount = previous != null && previous.active() && !user.getAccount().equals(previous.account())
                ? previous.account()
                : null;
        return new ScreenShareResponse(state, replacedAccount);
    }

    public MeetingRuntimeState stopScreenShare(String account, String meetingNo) {
        UserEntity user = userService.requireEnabledUserByAccount(account);
        MeetingRuntimeState state = getRuntime(meetingNo);
        if (state.screenShare != null && user.getAccount().equals(state.screenShare.account())) {
            state.screenShare = null;
            state.updatedAt = OffsetDateTime.now();
        }
        return state;
    }

    private MeetingEntity requireMeeting(String meetingNo) {
        MeetingEntity meeting = meetingRepository.findByMeetingNo(meetingNo)
                .orElseThrow(() -> new IllegalArgumentException("会议不存在"));
        if ("ENDED".equals(meeting.getStatus()) || "CANCELLED".equals(meeting.getStatus())) {
            throw new IllegalArgumentException("会议已结束");
        }
        return meeting;
    }

    public record MuteStateRequest(boolean muted) {
    }

    public record NetworkQualityRequest(
            String quality,
            Integer latencyMs,
            Double packetLossPercent,
            Integer audioBitrateKbps,
            Integer screenShareBitrateKbps
    ) {
    }

    public record StartScreenShareRequest(String scope, String sourceName) {
    }

    public record ScreenShareResponse(MeetingRuntimeState runtime, String replacedAccount) {
    }

    public static class MeetingRuntimeState {
        private final String meetingNo;
        private final Map<String, ParticipantRuntimeState> participants = new ConcurrentHashMap<>();
        private ScreenShareState screenShare;
        private OffsetDateTime updatedAt = OffsetDateTime.now();

        MeetingRuntimeState(String meetingNo) {
            this.meetingNo = meetingNo;
        }

        ParticipantRuntimeState participant(String account, String nickname) {
            return participants.compute(account, (ignored, existing) -> {
                if (existing == null) {
                    return new ParticipantRuntimeState(account, nickname);
                }
                existing.nickname = nickname;
                return existing;
            });
        }

        public String getMeetingNo() {
            return meetingNo;
        }

        public Map<String, ParticipantRuntimeState> getParticipants() {
            return participants;
        }

        public ScreenShareState getScreenShare() {
            return screenShare;
        }

        public OffsetDateTime getUpdatedAt() {
            return updatedAt;
        }
    }

    public static class ParticipantRuntimeState {
        private final String account;
        private String nickname;
        private boolean muted;
        private String networkQuality = "良好";
        private Integer latencyMs;
        private Double packetLossPercent;
        private Integer audioBitrateKbps;
        private Integer screenShareBitrateKbps;
        private OffsetDateTime updatedAt = OffsetDateTime.now();

        ParticipantRuntimeState(String account, String nickname) {
            this.account = account;
            this.nickname = nickname;
        }

        public String getAccount() {
            return account;
        }

        public String getNickname() {
            return nickname;
        }

        public boolean isMuted() {
            return muted;
        }

        public String getNetworkQuality() {
            return networkQuality;
        }

        public Integer getLatencyMs() {
            return latencyMs;
        }

        public Double getPacketLossPercent() {
            return packetLossPercent;
        }

        public Integer getAudioBitrateKbps() {
            return audioBitrateKbps;
        }

        public Integer getScreenShareBitrateKbps() {
            return screenShareBitrateKbps;
        }

        public OffsetDateTime getUpdatedAt() {
            return updatedAt;
        }
    }

    public record ScreenShareState(
            boolean active,
            String account,
            String nickname,
            String scope,
            String sourceName,
            OffsetDateTime startedAt
    ) {
    }
}
