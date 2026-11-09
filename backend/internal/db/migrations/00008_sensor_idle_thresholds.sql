-- Per-sensor idle thresholds (Alembic 008).

-- +goose Up
ALTER TABLE sensors ADD COLUMN idle_power_threshold_w FLOAT;
ALTER TABLE sensors ADD COLUMN idle_current_threshold_a FLOAT;
ALTER TABLE sensors ADD COLUMN idle_duration_seconds INTEGER;

-- +goose Down
ALTER TABLE sensors DROP COLUMN idle_duration_seconds;
ALTER TABLE sensors DROP COLUMN idle_current_threshold_a;
ALTER TABLE sensors DROP COLUMN idle_power_threshold_w;
