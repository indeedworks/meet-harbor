-- Remote Meeting System V1 PostgreSQL initialization script.
-- Target: PostgreSQL 14+

BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    account VARCHAR(64) NOT NULL UNIQUE,
    nickname VARCHAR(64) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    CONSTRAINT chk_users_role CHECK (role IN ('ADMIN', 'USER')),
    CONSTRAINT chk_users_status CHECK (status IN ('ENABLED', 'DISABLED'))
);

CREATE TABLE IF NOT EXISTS meetings (
    id BIGSERIAL PRIMARY KEY,
    meeting_no VARCHAR(32) NOT NULL UNIQUE,
    password_hash VARCHAR(255),
    topic VARCHAR(128) NOT NULL,
    meeting_type VARCHAR(32) NOT NULL,
    host_user_id BIGINT NOT NULL REFERENCES users(id),
    status VARCHAR(32) NOT NULL,
    scheduled_start_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_meetings_type CHECK (meeting_type IN ('INSTANT', 'SCHEDULED')),
    CONSTRAINT chk_meetings_status CHECK (
        status IN ('SCHEDULED', 'WAITING', 'IN_PROGRESS', 'ENDED', 'CANCELLED')
    )
);

CREATE TABLE IF NOT EXISTS meeting_members (
    id BIGSERIAL PRIMARY KEY,
    meeting_id BIGINT NOT NULL REFERENCES meetings(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    meeting_role VARCHAR(32) NOT NULL,
    first_joined_at TIMESTAMPTZ,
    last_left_at TIMESTAMPTZ,
    total_duration_seconds INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (meeting_id, user_id),
    CONSTRAINT chk_meeting_members_role CHECK (meeting_role IN ('HOST', 'PARTICIPANT')),
    CONSTRAINT chk_meeting_members_duration CHECK (total_duration_seconds >= 0)
);

CREATE TABLE IF NOT EXISTS meeting_sessions (
    id BIGSERIAL PRIMARY KEY,
    meeting_id BIGINT NOT NULL REFERENCES meetings(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    client_session_id VARCHAR(128) NOT NULL,
    join_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    leave_at TIMESTAMPTZ,
    leave_reason VARCHAR(64),
    reconnect_count INTEGER NOT NULL DEFAULT 0,
    client_ip VARCHAR(64),
    user_agent VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_meeting_sessions_leave_reason CHECK (
        leave_reason IS NULL OR leave_reason IN (
            'NORMAL',
            'NETWORK_DISCONNECT',
            'CLIENT_CRASH',
            'SERVER_KICK',
            'UNKNOWN'
        )
    ),
    CONSTRAINT chk_meeting_sessions_reconnect_count CHECK (reconnect_count >= 0)
);

CREATE TABLE IF NOT EXISTS recordings (
    id BIGSERIAL PRIMARY KEY,
    meeting_id BIGINT NOT NULL REFERENCES meetings(id),
    started_by BIGINT NOT NULL REFERENCES users(id),
    stopped_by BIGINT REFERENCES users(id),
    status VARCHAR(32) NOT NULL,
    file_path VARCHAR(512),
    file_name VARCHAR(255),
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMPTZ,
    stopped_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    expired_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_recordings_status CHECK (
        status IN (
            'NOT_STARTED',
            'RECORDING',
            'PROCESSING',
            'COMPLETED',
            'FAILED',
            'EXPIRED',
            'DELETED'
        )
    ),
    CONSTRAINT chk_recordings_file_size CHECK (file_size_bytes >= 0),
    CONSTRAINT chk_recordings_duration CHECK (duration_seconds >= 0)
);

CREATE TABLE IF NOT EXISTS recording_download_logs (
    id BIGSERIAL PRIMARY KEY,
    recording_id BIGINT NOT NULL REFERENCES recordings(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    download_source VARCHAR(32) NOT NULL,
    client_ip VARCHAR(64),
    user_agent VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_recording_download_logs_source CHECK (download_source IN ('CLIENT', 'ADMIN'))
);

CREATE TABLE IF NOT EXISTS operation_logs (
    id BIGSERIAL PRIMARY KEY,
    operator_id BIGINT REFERENCES users(id),
    action VARCHAR(64) NOT NULL,
    target_type VARCHAR(64),
    target_id BIGINT,
    client_ip VARCHAR(64),
    user_agent VARCHAR(255),
    detail JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_operation_logs_action CHECK (action <> '')
);

ALTER TABLE operation_logs DROP CONSTRAINT IF EXISTS chk_operation_logs_action;
ALTER TABLE operation_logs ADD CONSTRAINT chk_operation_logs_action CHECK (
    action IN (
        'LOGIN',
        'CREATE_MEETING',
        'JOIN_MEETING',
        'LEAVE_MEETING',
        'START_RECORDING',
        'STOP_RECORDING',
        'DOWNLOAD_RECORDING',
        'DELETE_RECORDING',
        'FORCE_STOP_MEETING',
        'CREATE_USER',
        'UPDATE_USER',
        'DISABLE_USER',
        'ENABLE_USER',
        'RESET_PASSWORD',
        'CHANGE_PASSWORD'
    )
);

CREATE TABLE IF NOT EXISTS storage_snapshots (
    id BIGSERIAL PRIMARY KEY,
    total_bytes BIGINT NOT NULL,
    used_bytes BIGINT NOT NULL,
    free_bytes BIGINT NOT NULL,
    recording_used_bytes BIGINT NOT NULL,
    expiring_recording_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_storage_snapshots_total CHECK (total_bytes >= 0),
    CONSTRAINT chk_storage_snapshots_used CHECK (used_bytes >= 0),
    CONSTRAINT chk_storage_snapshots_free CHECK (free_bytes >= 0),
    CONSTRAINT chk_storage_snapshots_recording_used CHECK (recording_used_bytes >= 0),
    CONSTRAINT chk_storage_snapshots_expiring_count CHECK (expiring_recording_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_meetings_host_user_id ON meetings(host_user_id);
CREATE INDEX IF NOT EXISTS idx_meetings_status ON meetings(status);
CREATE INDEX IF NOT EXISTS idx_meetings_started_at ON meetings(started_at);

CREATE INDEX IF NOT EXISTS idx_meeting_members_meeting_id ON meeting_members(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_members_user_id ON meeting_members(user_id);

CREATE INDEX IF NOT EXISTS idx_meeting_sessions_meeting_id ON meeting_sessions(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_sessions_user_id ON meeting_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_meeting_sessions_client_session_id ON meeting_sessions(client_session_id);

CREATE INDEX IF NOT EXISTS idx_recordings_meeting_id ON recordings(meeting_id);
CREATE INDEX IF NOT EXISTS idx_recordings_status ON recordings(status);
CREATE INDEX IF NOT EXISTS idx_recordings_expired_at ON recordings(expired_at);

CREATE INDEX IF NOT EXISTS idx_recording_download_logs_recording_id ON recording_download_logs(recording_id);
CREATE INDEX IF NOT EXISTS idx_recording_download_logs_user_id ON recording_download_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_operation_logs_operator_id ON operation_logs(operator_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_action ON operation_logs(action);
CREATE INDEX IF NOT EXISTS idx_operation_logs_created_at ON operation_logs(created_at);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON users;
CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_meetings_set_updated_at ON meetings;
CREATE TRIGGER trg_meetings_set_updated_at
BEFORE UPDATE ON meetings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_meeting_members_set_updated_at ON meeting_members;
CREATE TRIGGER trg_meeting_members_set_updated_at
BEFORE UPDATE ON meeting_members
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_recordings_set_updated_at ON recordings;
CREATE TRIGGER trg_recordings_set_updated_at
BEFORE UPDATE ON recordings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
