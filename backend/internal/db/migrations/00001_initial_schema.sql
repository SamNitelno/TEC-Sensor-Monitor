-- Initial schema with TimescaleDB hypertable for readings (Alembic 001).
-- +goose NO TRANSACTION

-- +goose Up
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('admin', 'viewer');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd

-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE sensor_status AS ENUM ('online', 'offline');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd

-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE downtime_type AS ENUM ('offline', 'idle');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd

CREATE TABLE users (
    id SERIAL NOT NULL,
    login VARCHAR(64) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (login)
);

CREATE TABLE sites (
    id SERIAL NOT NULL,
    name VARCHAR(255) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE workshops (
    id SERIAL NOT NULL,
    name VARCHAR(255) NOT NULL,
    site_id INTEGER NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (site_id) REFERENCES sites (id)
);

CREATE TABLE sensors (
    id SERIAL NOT NULL,
    name VARCHAR(255) NOT NULL,
    device_id VARCHAR(64) NOT NULL,
    api_token VARCHAR(255) NOT NULL,
    workshop_id INTEGER,
    status sensor_status DEFAULT 'offline' NOT NULL,
    last_seen TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (workshop_id) REFERENCES workshops (id),
    UNIQUE (device_id),
    UNIQUE (api_token)
);

CREATE TABLE readings (
    time TIMESTAMP WITH TIME ZONE NOT NULL,
    sensor_id INTEGER NOT NULL,
    current_a FLOAT NOT NULL,
    PRIMARY KEY (time, sensor_id),
    FOREIGN KEY (sensor_id) REFERENCES sensors (id)
);

SELECT create_hypertable('readings', 'time', if_not_exists => TRUE);

CREATE INDEX ix_readings_sensor_id_time_desc ON readings (sensor_id, time DESC);

CREATE TABLE downtime_events (
    id SERIAL NOT NULL,
    sensor_id INTEGER NOT NULL,
    type downtime_type NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (id),
    FOREIGN KEY (sensor_id) REFERENCES sensors (id)
);

-- +goose Down
DROP TABLE IF EXISTS downtime_events;
DROP INDEX IF EXISTS ix_readings_sensor_id_time_desc;
DROP TABLE IF EXISTS readings;
DROP TABLE IF EXISTS sensors;
DROP TABLE IF EXISTS workshops;
DROP TABLE IF EXISTS sites;
DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS downtime_type;
DROP TYPE IF EXISTS sensor_status;
DROP TYPE IF EXISTS user_role;
DROP EXTENSION IF EXISTS timescaledb;
