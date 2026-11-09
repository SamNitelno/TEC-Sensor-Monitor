-- Add nullable power_w column to readings hypertable (Alembic 003).

-- +goose Up
ALTER TABLE readings ADD COLUMN power_w FLOAT;

-- +goose Down
ALTER TABLE readings DROP COLUMN power_w;
