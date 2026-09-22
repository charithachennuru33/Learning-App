CREATE TABLE platform_user (
    id UUID PRIMARY KEY,
    email VARCHAR(320) UNIQUE,
    phone VARCHAR(32) UNIQUE,
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT platform_user_identity_check CHECK (email IS NOT NULL OR phone IS NOT NULL)
);
