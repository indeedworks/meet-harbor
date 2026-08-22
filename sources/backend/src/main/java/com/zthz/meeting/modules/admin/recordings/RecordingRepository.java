package com.zthz.meeting.modules.admin.recordings;

import java.util.List;
import java.time.OffsetDateTime;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface RecordingRepository extends JpaRepository<RecordingEntity, Long> {
    boolean existsByMeetingId(Long meetingId);

    boolean existsByMeetingIdAndStatus(Long meetingId, String status);

    long countByStatus(String status);

    long countByExpiredAtBetween(OffsetDateTime start, OffsetDateTime end);

    @Query("select coalesce(sum(recording.fileSizeBytes), 0) from RecordingEntity recording where recording.status <> 'DELETED'")
    long sumActiveFileSizeBytes();

    @EntityGraph(attributePaths = "meeting")
    List<RecordingEntity> findAllByOrderByCreatedAtDesc();
}
