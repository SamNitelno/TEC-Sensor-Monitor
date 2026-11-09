-- Continuous aggregates for readings time-series charts (Alembic 002).
SELECT remove_continuous_aggregate_policy('readings_day', if_exists => true);
DROP MATERIALIZED VIEW IF EXISTS readings_day;
SELECT remove_continuous_aggregate_policy('readings_hour', if_exists => true);
DROP MATERIALIZED VIEW IF EXISTS readings_hour;
SELECT remove_continuous_aggregate_policy('readings_minute', if_exists => true);
DROP MATERIALIZED VIEW IF EXISTS readings_minute;
