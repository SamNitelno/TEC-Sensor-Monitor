-- Contact (email/phone) verification batches (Alembic 011).

-- +goose Up
CREATE TABLE contact_verification_batches (
    id VARCHAR(36) NOT NULL,
    user_id INTEGER NOT NULL,
    pending_login VARCHAR(64),
    pending_email VARCHAR(255),
    pending_phone VARCHAR(32),
    clear_email BOOLEAN DEFAULT 'false' NOT NULL,
    clear_phone BOOLEAN DEFAULT 'false' NOT NULL,
    email_code_hash VARCHAR(64),
    phone_code_hash VARCHAR(64),
    email_verified BOOLEAN DEFAULT 'false' NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE INDEX ix_contact_verification_batches_user_id ON contact_verification_batches (user_id);

-- +goose Down
DROP INDEX IF EXISTS ix_contact_verification_batches_user_id;
DROP TABLE IF EXISTS contact_verification_batches;
