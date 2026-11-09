-- Continuous aggregates with power_w, compression and retention (Alembic 012).
SELECT remove_retention_policy('readings', if_exists => true);
SELECT remove_compression_policy('readings', if_exists => true);
SELECT remove_continuous_aggregate_policy('readings_day', if_exists => true);
DROP MATERIALIZED VIEW IF EXISTS readings_day;
SELECT remove_continuous_aggregate_policy('readings_hour', if_exists => true);
DROP MATERIALIZED VIEW IF EXISTS readings_hour;
SELECT remove_continuous_aggregate_policy('readings_minute', if_exists => true);
DROP MATERIALIZED VIEW IF EXISTS readings_minute;
