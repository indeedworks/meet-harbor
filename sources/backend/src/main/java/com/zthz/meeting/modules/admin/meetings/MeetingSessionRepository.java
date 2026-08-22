package com.zthz.meeting.modules.admin.meetings;

import java.util.Optional;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MeetingSessionRepository extends JpaRepository<MeetingSessionEntity, Long> {
    long countByMeetingIdAndLeaveAtIsNull(Long meetingId);

    Optional<MeetingSessionEntity> findByClientSessionIdAndLeaveAtIsNull(String clientSessionId);

    Optional<MeetingSessionEntity> findFirstByMeetingIdAndUserAccountAndLeaveAtIsNullOrderByJoinAtDesc(Long meetingId, String account);

    List<MeetingSessionEntity> findAllByMeetingIdAndLeaveAtIsNull(Long meetingId);
}
