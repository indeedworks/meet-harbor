package com.zthz.meeting.modules.admin.meetings;

import com.zthz.meeting.modules.admin.users.UserEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;

@Entity
@Table(name = "meeting_members")
public class MeetingMemberEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "meeting_id", nullable = false)
    private MeetingEntity meeting;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private UserEntity user;

    @Column(name = "meeting_role", nullable = false, length = 32)
    private String meetingRole;

    @Column(name = "first_joined_at")
    private OffsetDateTime firstJoinedAt;

    @Column(name = "last_left_at")
    private OffsetDateTime lastLeftAt;

    @Column(name = "total_duration_seconds", nullable = false)
    private Integer totalDurationSeconds;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public Long getId() {
        return id;
    }

    public MeetingEntity getMeeting() {
        return meeting;
    }

    public UserEntity getUser() {
        return user;
    }

    public String getMeetingRole() {
        return meetingRole;
    }

    public OffsetDateTime getFirstJoinedAt() {
        return firstJoinedAt;
    }

    public OffsetDateTime getLastLeftAt() {
        return lastLeftAt;
    }

    public Integer getTotalDurationSeconds() {
        return totalDurationSeconds;
    }

    public void setMeeting(MeetingEntity meeting) {
        this.meeting = meeting;
    }

    public void setUser(UserEntity user) {
        this.user = user;
    }

    public void setMeetingRole(String meetingRole) {
        this.meetingRole = meetingRole;
    }

    public void setFirstJoinedAt(OffsetDateTime firstJoinedAt) {
        this.firstJoinedAt = firstJoinedAt;
    }

    public void setLastLeftAt(OffsetDateTime lastLeftAt) {
        this.lastLeftAt = lastLeftAt;
    }

    public void setTotalDurationSeconds(Integer totalDurationSeconds) {
        this.totalDurationSeconds = totalDurationSeconds;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public void setUpdatedAt(OffsetDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
