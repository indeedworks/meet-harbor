package com.zthz.meeting.modules.admin.meetings;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface MeetingMemberRepository extends JpaRepository<MeetingMemberEntity, Long> {
    boolean existsByMeetingIdAndUserAccount(Long meetingId, String account);
    int countByMeetingId(Long meetingId);

    Optional<MeetingMemberEntity> findByMeetingIdAndUserId(Long meetingId, Long userId);

    @Query("""
            select count(distinct member.user.id)
            from MeetingMemberEntity member
            where member.meeting.status = 'IN_PROGRESS'
            """)
    long countOnlineUsers();
}
