package com.zthz.meeting.modules.admin.meetings;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MeetingRepository extends JpaRepository<MeetingEntity, Long> {
    boolean existsByMeetingNo(String meetingNo);

    Optional<MeetingEntity> findByMeetingNo(String meetingNo);

    long countByStatus(String status);

    @EntityGraph(attributePaths = "hostUser")
    List<MeetingEntity> findByStatusOrderByStartedAtDesc(String status);

    @EntityGraph(attributePaths = "hostUser")
    List<MeetingEntity> findByStatusNotOrderByStartedAtDesc(String status);
}
