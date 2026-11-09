-- Remove orphan sites without workshop_id from QA runs (Alembic 005).

-- +goose Up
DELETE FROM sites
WHERE workshop_id IS NULL
  AND id NOT IN (
    SELECT DISTINCT site_id FROM sensors WHERE site_id IS NOT NULL
  );

UPDATE sites
SET workshop_id = (SELECT id FROM workshops ORDER BY id LIMIT 1)
WHERE workshop_id IS NULL;

-- +goose Down
SELECT 1;
