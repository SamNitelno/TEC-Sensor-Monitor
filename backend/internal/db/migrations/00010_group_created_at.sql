-- created_at on workshops and sites (Alembic 010).

-- +goose Up
ALTER TABLE workshops ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL;
ALTER TABLE sites ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL;

-- +goose Down
ALTER TABLE sites DROP COLUMN created_at;
ALTER TABLE workshops DROP COLUMN created_at;
