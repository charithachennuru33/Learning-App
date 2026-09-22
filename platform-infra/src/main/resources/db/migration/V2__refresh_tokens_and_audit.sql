CREATE TABLE refresh_token (
    id          UUID PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES platform_user (id) ON DELETE CASCADE,
    family_id   UUID         NOT NULL,
    token_hash  VARCHAR(64)  NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ  NOT NULL,
    expires_at  TIMESTAMPTZ  NOT NULL,
    revoked_at  TIMESTAMPTZ,
    replaced_by UUID,
    created_ip  VARCHAR(45),
    user_agent  VARCHAR(255)
);

CREATE INDEX idx_refresh_token_family ON refresh_token (family_id);
CREATE INDEX idx_refresh_token_user ON refresh_token (user_id);
CREATE INDEX idx_refresh_token_expires_at ON refresh_token (expires_at);

-- No FK to platform_user: audit history must outlive deleted users.
CREATE TABLE auth_audit_event (
    id         UUID PRIMARY KEY,
    event_type VARCHAR(64)  NOT NULL,
    user_id    UUID,
    subject    VARCHAR(64),
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    details    VARCHAR(500),
    created_at TIMESTAMPTZ  NOT NULL
);

CREATE INDEX idx_auth_audit_event_user ON auth_audit_event (user_id, created_at);
CREATE INDEX idx_auth_audit_event_type ON auth_audit_event (event_type, created_at);
