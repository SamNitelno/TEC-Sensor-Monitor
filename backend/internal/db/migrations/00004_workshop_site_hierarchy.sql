-- Workshop -> Site -> Sensor hierarchy (sites inside workshops) (Alembic 004).

-- +goose Up
ALTER TABLE sites ADD COLUMN workshop_id INTEGER;
ALTER TABLE sensors ADD COLUMN site_id INTEGER;

-- First workshop per legacy site keeps the existing site row.
UPDATE sites s
SET workshop_id = w.id
FROM (
    SELECT DISTINCT ON (site_id) id, site_id
    FROM workshops
    ORDER BY site_id, id
) w
WHERE s.id = w.site_id;

-- Additional workshops under the same legacy site get dedicated site rows.
INSERT INTO sites (name, workshop_id)
SELECT s.name || ' (' || w.name || ')', w.id
FROM workshops w
JOIN sites s ON w.site_id = s.id
WHERE NOT EXISTS (
    SELECT 1 FROM sites s2 WHERE s2.workshop_id = w.id
);

UPDATE sensors sen
SET site_id = (
    SELECT s.id FROM sites s
    WHERE s.workshop_id = sen.workshop_id
    ORDER BY s.id
    LIMIT 1
)
WHERE sen.workshop_id IS NOT NULL;

ALTER TABLE sensors DROP CONSTRAINT sensors_workshop_id_fkey;
ALTER TABLE sensors DROP COLUMN workshop_id;

ALTER TABLE workshops DROP CONSTRAINT workshops_site_id_fkey;
ALTER TABLE workshops DROP COLUMN site_id;

ALTER TABLE sites ADD CONSTRAINT sites_workshop_id_fkey FOREIGN KEY (workshop_id) REFERENCES workshops (id);
ALTER TABLE sensors ADD CONSTRAINT sensors_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites (id);

-- +goose Down
ALTER TABLE workshops ADD COLUMN site_id INTEGER;
ALTER TABLE sensors ADD COLUMN workshop_id INTEGER;
UPDATE workshops w SET site_id = s.id FROM sites s WHERE s.workshop_id = w.id;
UPDATE sensors sen SET workshop_id = s.workshop_id FROM sites s WHERE sen.site_id = s.id;
ALTER TABLE sensors DROP CONSTRAINT sensors_site_id_fkey;
ALTER TABLE sensors DROP COLUMN site_id;
ALTER TABLE sites DROP CONSTRAINT sites_workshop_id_fkey;
ALTER TABLE sites DROP COLUMN workshop_id;
ALTER TABLE workshops ADD CONSTRAINT workshops_site_id_fkey FOREIGN KEY (site_id) REFERENCES sites (id);
ALTER TABLE sensors ADD CONSTRAINT sensors_workshop_id_fkey FOREIGN KEY (workshop_id) REFERENCES workshops (id);
