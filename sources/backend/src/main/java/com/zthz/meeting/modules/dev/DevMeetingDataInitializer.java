package com.zthz.meeting.modules.dev;

import com.zthz.meeting.modules.admin.meetings.MeetingEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingMemberEntity;
import com.zthz.meeting.modules.admin.meetings.MeetingMemberRepository;
import com.zthz.meeting.modules.admin.meetings.MeetingRepository;
import com.zthz.meeting.modules.admin.recordings.RecordingEntity;
import com.zthz.meeting.modules.admin.recordings.RecordingRepository;
import com.zthz.meeting.modules.admin.users.UserEntity;
import com.zthz.meeting.modules.admin.users.UserRepository;
import java.time.OffsetDateTime;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@Order(1)
@ConditionalOnProperty(name = "app.bootstrap.demo-data-enabled", havingValue = "true")
public class DevMeetingDataInitializer implements ApplicationRunner {

    private final UserRepository userRepository;
    private final MeetingRepository meetingRepository;
    private final MeetingMemberRepository meetingMemberRepository;
    private final RecordingRepository recordingRepository;
    private final PasswordEncoder passwordEncoder;

    public DevMeetingDataInitializer(
            UserRepository userRepository,
            MeetingRepository meetingRepository,
            MeetingMemberRepository meetingMemberRepository,
            RecordingRepository recordingRepository,
            PasswordEncoder passwordEncoder
    ) {
        this.userRepository = userRepository;
        this.meetingRepository = meetingRepository;
        this.meetingMemberRepository = meetingMemberRepository;
        this.recordingRepository = recordingRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (meetingRepository.count() > 0) {
            return;
        }

        UserEntity admin = userRepository.findByAccount("admin")
                .orElseThrow(() -> new IllegalStateException("默认管理员不存在"));
        UserEntity zhangsan = ensureUser("zhangsan", "张三");
        UserEntity lisi = ensureUser("lisi", "李四");

        OffsetDateTime now = OffsetDateTime.now();
        MeetingEntity online = createMeeting("83624519", "产品周会", admin, "IN_PROGRESS", now.minusMinutes(43), null);
        MeetingEntity historyWithRecording = createMeeting("90218466", "项目启动会", zhangsan, "ENDED", now.minusDays(1).minusHours(2), now.minusDays(1).minusHours(1));
        MeetingEntity historyWithoutRecording = createMeeting("72193054", "客户沟通", lisi, "ENDED", now.minusDays(2).minusHours(4), now.minusDays(2).minusHours(3));

        addMember(online, admin, "HOST", online.getStartedAt(), null, 0);
        addMember(historyWithRecording, zhangsan, "HOST", historyWithRecording.getStartedAt(), historyWithRecording.getEndedAt(), 3600);
        addMember(historyWithoutRecording, lisi, "HOST", historyWithoutRecording.getStartedAt(), historyWithoutRecording.getEndedAt(), 3600);

        createRecording(historyWithRecording, zhangsan, "COMPLETED", "90218466-20260707.mp4", 386_924_544L, now.minusDays(1).minusHours(1), now.plusDays(6));
        createRecording(online, admin, "RECORDING", null, 0L, now.minusMinutes(30), null);
    }

    private UserEntity ensureUser(String account, String nickname) {
        return userRepository.findByAccount(account).orElseGet(() -> {
            OffsetDateTime now = OffsetDateTime.now();
            UserEntity user = new UserEntity();
            user.setAccount(account);
            user.setNickname(nickname);
            user.setPasswordHash(passwordEncoder.encode("Aa123456"));
            user.setRole("USER");
            user.setStatus("ENABLED");
            user.setCreatedAt(now);
            user.setUpdatedAt(now);
            return userRepository.save(user);
        });
    }

    private MeetingEntity createMeeting(
            String meetingNo,
            String topic,
            UserEntity host,
            String status,
            OffsetDateTime startedAt,
            OffsetDateTime endedAt
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        MeetingEntity meeting = new MeetingEntity();
        meeting.setMeetingNo(meetingNo);
        meeting.setPasswordHash(passwordEncoder.encode("123456"));
        meeting.setTopic(topic);
        meeting.setMeetingType("INSTANT");
        meeting.setHostUser(host);
        meeting.setStatus(status);
        meeting.setStartedAt(startedAt);
        meeting.setEndedAt(endedAt);
        meeting.setCreatedAt(now);
        meeting.setUpdatedAt(now);
        return meetingRepository.save(meeting);
    }

    private void addMember(
            MeetingEntity meeting,
            UserEntity user,
            String role,
            OffsetDateTime joinedAt,
            OffsetDateTime leftAt,
            int durationSeconds
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        MeetingMemberEntity member = new MeetingMemberEntity();
        member.setMeeting(meeting);
        member.setUser(user);
        member.setMeetingRole(role);
        member.setFirstJoinedAt(joinedAt);
        member.setLastLeftAt(leftAt);
        member.setTotalDurationSeconds(durationSeconds);
        member.setCreatedAt(now);
        member.setUpdatedAt(now);
        meetingMemberRepository.save(member);
    }

    private void createRecording(
            MeetingEntity meeting,
            UserEntity operator,
            String status,
            String fileName,
            long fileSizeBytes,
            OffsetDateTime startedAt,
            OffsetDateTime expiredAt
    ) {
        OffsetDateTime now = OffsetDateTime.now();
        RecordingEntity recording = new RecordingEntity();
        recording.setMeeting(meeting);
        recording.setStartedBy(operator);
        recording.setStoppedBy("RECORDING".equals(status) ? null : operator);
        recording.setStatus(status);
        recording.setFilePath(fileName == null ? null : "/data/recordings/" + meeting.getMeetingNo() + "/" + fileName);
        recording.setFileName(fileName);
        recording.setFileSizeBytes(fileSizeBytes);
        recording.setDurationSeconds("RECORDING".equals(status) ? 0 : 3600);
        recording.setStartedAt(startedAt);
        recording.setStoppedAt("RECORDING".equals(status) ? null : startedAt.plusHours(1));
        recording.setCompletedAt("COMPLETED".equals(status) ? startedAt.plusHours(1).plusMinutes(3) : null);
        recording.setExpiredAt(expiredAt);
        recording.setCreatedAt(now);
        recording.setUpdatedAt(now);
        recordingRepository.save(recording);
    }
}
