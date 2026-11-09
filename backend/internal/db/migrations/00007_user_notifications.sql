-- Per-user notifications (Alembic 007).

-- +goose Up
CREATE TABLE user_notifications (
    id SERIAL NOT NULL,
    user_id INTEGER NOT NULL,
    message VARCHAR(512) NOT NULL,
    kind VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (id),
    FOREIGN KEY (user_id) REFERENCES users (id)
);
CREATE INDEX ix_user_notifications_user_id ON user_notifications (user_id);

-- +goose Down
DROP INDEX IF EXISTS ix_user_notifications_user_id;
DROP TABLE IF EXISTS user_notifications;
