-- Continuous aggregates for readings time-series charts (Alembic 002).
-- Executed statement by statement outside a transaction (see migrate.go).
CREATE MATERIALIZED VIEW readings_minute
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', time) AS bucket,
    sensor_id,
    AVG(current_a) AS avg_current_a,
    MIN(current_a) AS min_current_a,
    MAX(current_a) AS max_current_a
FROM readings
GROUP BY bucket, sensor_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
    'readings_minute',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute'
);

CREATE MATERIALIZED VIEW readings_hour
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    sensor_id,
    AVG(current_a) AS avg_current_a,
    MIN(current_a) AS min_current_a,
    MAX(current_a) AS max_current_a
FROM readings
GROUP BY bucket, sensor_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
    'readings_hour',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

CREATE MATERIALIZED VIEW readings_day
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', time) AS bucket,
    sensor_id,
    AVG(current_a) AS avg_current_a,
    MIN(current_a) AS min_current_a,
    MAX(current_a) AS max_current_a
FROM readings
GROUP BY bucket, sensor_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy(
    'readings_day',
    start_offset => INTERVAL '30 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);

CALL refresh_continuous_aggregate('readings_minute', NULL, NULL);
CALL refresh_continuous_aggregate('readings_hour', NULL, NULL);
CALL refresh_continuous_aggregate('readings_day', NULL, NULL);
