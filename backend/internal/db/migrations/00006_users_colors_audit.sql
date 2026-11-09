-- Users contacts/hierarchy, entity colours, sensor placement audit (Alembic 006).

-- +goose Up
ALTER TABLE users ADD COLUMN email VARCHAR(255);
ALTER TABLE users ADD COLUMN phone VARCHAR(32);
ALTER TABLE users ADD COLUMN promoted_by_user_id INTEGER;
ALTER TABLE users ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT true NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_promoted_by_user_id_fkey FOREIGN KEY (promoted_by_user_id) REFERENCES users (id);
CREATE UNIQUE INDEX ix_users_email ON users (email);

ALTER TABLE workshops ADD COLUMN color VARCHAR(7);
ALTER TABLE sites ADD COLUMN color VARCHAR(7);
ALTER TABLE sensors ADD COLUMN color VARCHAR(7);
ALTER TABLE sensors ADD COLUMN created_by_user_id INTEGER;
ALTER TABLE sensors ADD CONSTRAINT sensors_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES users (id);

CREATE TABLE sensor_placement_history (
    id SERIAL NOT NULL,
    sensor_id INTEGER NOT NULL,
    site_id INTEGER,
    assigned_by_user_id INTEGER,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (sensor_id) REFERENCES sensors (id),
    FOREIGN KEY (site_id) REFERENCES sites (id),
    FOREIGN KEY (assigned_by_user_id) REFERENCES users (id)
);
CREATE INDEX ix_sensor_placement_history_sensor_id ON sensor_placement_history (sensor_id);

-- +goose Down
DROP INDEX IF EXISTS ix_sensor_placement_history_sensor_id;
DROP TABLE IF EXISTS sensor_placement_history;
ALTER TABLE sensors DROP CONSTRAINT IF EXISTS sensors_created_by_user_id_fkey;
ALTER TABLE sensors DROP COLUMN IF EXISTS created_by_user_id;
ALTER TABLE sensors DROP COLUMN IF EXISTS color;
ALTER TABLE sites DROP COLUMN IF EXISTS color;
ALTER TABLE workshops DROP COLUMN IF EXISTS color;
DROP INDEX IF EXISTS ix_users_email;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_promoted_by_user_id_fkey;
ALTER TABLE users DROP COLUMN IF EXISTS is_active;
ALTER TABLE users DROP COLUMN IF EXISTS updated_at;
ALTER TABLE users DROP COLUMN IF EXISTS promoted_by_user_id;
ALTER TABLE users DROP COLUMN IF EXISTS phone;
ALTER TABLE users DROP COLUMN IF EXISTS email;
