-- Notification toggles on workshops/sites/sensors (Alembic 009).

-- +goose Up
ALTER TABLE workshops ADD COLUMN notifications_enabled BOOLEAN DEFAULT true NOT NULL;
ALTER TABLE sites ADD COLUMN notifications_enabled BOOLEAN DEFAULT true NOT NULL;
ALTER TABLE sensors ADD COLUMN notifications_enabled BOOLEAN DEFAULT true NOT NULL;

-- +goose Down
ALTER TABLE sensors DROP COLUMN notifications_enabled;
ALTER TABLE sites DROP COLUMN notifications_enabled;
ALTER TABLE workshops DROP COLUMN notifications_enabled;
