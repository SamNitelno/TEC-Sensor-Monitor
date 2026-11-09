-- Case-insensitive email/phone uniqueness, password reset batches (Alembic 014).

-- +goose Up
UPDATE users SET email = LOWER(TRIM(email)) WHERE email IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email_lower
ON users (LOWER(email))
WHERE email IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ix_users_phone
ON users (phone)
WHERE phone IS NOT NULL;

CREATE TABLE password_reset_batches (
    id VARCHAR(36) NOT NULL,
    user_id INTEGER NOT NULL,
    channel VARCHAR(16) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    code_hash VARCHAR(64) NOT NULL,
    failed_attempts INTEGER DEFAULT '0' NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    consumed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE INDEX ix_password_reset_batches_user_id ON password_reset_batches (user_id);

-- +goose Down
DROP INDEX IF EXISTS ix_password_reset_batches_user_id;
DROP TABLE IF EXISTS password_reset_batches;
DROP INDEX IF EXISTS ix_users_phone;
DROP INDEX IF EXISTS ix_users_email_lower;
