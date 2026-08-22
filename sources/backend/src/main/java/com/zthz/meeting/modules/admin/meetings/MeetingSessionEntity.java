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
@Table(name = "meeting_sessions")
public class MeetingSessionEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "meeting_id", nullable = false)
    private MeetingEntity meeting;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private UserEntity user;

    @Column(name = "client_session_id", nullable = false, length = 128)
    private String clientSessionId;

    @Column(name = "join_at", nullable = false)
    private OffsetDateTime joinAt;

    @Column(name = "leave_at")
    private OffsetDateTime leaveAt;

    @Column(name = "leave_reason", length = 64)
    private String leaveReason;

    @Column(name = "reconnect_count", nullable = false)
    private Integer reconnectCount;

    @Column(name = "client_ip", length = 64)
    private String clientIp;

    @Column(name = "user_agent")
    private String userAgent;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    public Long getId() {
        return id;
    }

    public MeetingEntity getMeeting() {
        return meeting;
    }

    public UserEntity getUser() {
        return user;
    }

    public String getClientSessionId() {
        return clientSessionId;
    }

    public OffsetDateTime getJoinAt() {
        return joinAt;
    }

    public OffsetDateTime getLeaveAt() {
        return leaveAt;
    }

    public Integer getReconnectCount() {
        return reconnectCount;
    }

    public void setMeeting(MeetingEntity meeting) {
        this.meeting = meeting;
    }

    public void setUser(UserEntity user) {
        this.user = user;
    }

    public void setClientSessionId(String clientSessionId) {
        this.clientSessionId = clientSessionId;
    }

    public void setJoinAt(OffsetDateTime joinAt) {
        this.joinAt = joinAt;
    }

    public void setLeaveAt(OffsetDateTime leaveAt) {
        this.leaveAt = leaveAt;
    }

    public void setLeaveReason(String leaveReason) {
        this.leaveReason = leaveReason;
    }

    public void setReconnectCount(Integer reconnectCount) {
        this.reconnectCount = reconnectCount;
    }

    public void setClientIp(String clientIp) {
        this.clientIp = clientIp;
    }

    public void setUserAgent(String userAgent) {
        this.userAgent = userAgent;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
