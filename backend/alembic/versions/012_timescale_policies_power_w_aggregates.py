"""TimescaleDB: power_w in continuous aggregates, compression and retention policies."""

from typing import Sequence, Union

from alembic import op

revision: str = "012"
down_revision: Union[str, None] = "011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _drop_aggregate(name: str) -> None:
    op.execute(
        f"SELECT remove_continuous_aggregate_policy('{name}', if_exists => true)"
    )
    op.execute(f"DROP MATERIALIZED VIEW IF EXISTS {name}")


def upgrade() -> None:
    with op.get_context().autocommit_block():
        for name in ("readings_day", "readings_hour", "readings_minute"):
            _drop_aggregate(name)

        op.execute(
            """
            CREATE MATERIALIZED VIEW readings_minute
            WITH (timescaledb.continuous) AS
            SELECT
                time_bucket('1 minute', time) AS bucket,
                sensor_id,
                AVG(current_a) AS avg_current_a,
                MIN(current_a) AS min_current_a,
                MAX(current_a) AS max_current_a,
                AVG(power_w) AS avg_power_w,
                MIN(power_w) AS min_power_w,
                MAX(power_w) AS max_power_w
            FROM readings
            GROUP BY bucket, sensor_id
            WITH NO DATA
            """
        )
        op.execute(
            """
            SELECT add_continuous_aggregate_policy(
                'readings_minute',
                start_offset => INTERVAL '3 hours',
                end_offset => INTERVAL '1 minute',
                schedule_interval => INTERVAL '1 minute'
            )
            """
        )

        op.execute(
            """
            CREATE MATERIALIZED VIEW readings_hour
            WITH (timescaledb.continuous) AS
            SELECT
                time_bucket('1 hour', time) AS bucket,
                sensor_id,
                AVG(current_a) AS avg_current_a,
                MIN(current_a) AS min_current_a,
                MAX(current_a) AS max_current_a,
                AVG(power_w) AS avg_power_w,
                MIN(power_w) AS min_power_w,
                MAX(power_w) AS max_power_w
            FROM readings
            GROUP BY bucket, sensor_id
            WITH NO DATA
            """
        )
        op.execute(
            """
            SELECT add_continuous_aggregate_policy(
                'readings_hour',
                start_offset => INTERVAL '3 days',
                end_offset => INTERVAL '1 hour',
                schedule_interval => INTERVAL '1 hour'
            )
            """
        )

        op.execute(
            """
            CREATE MATERIALIZED VIEW readings_day
            WITH (timescaledb.continuous) AS
            SELECT
                time_bucket('1 day', time) AS bucket,
                sensor_id,
                AVG(current_a) AS avg_current_a,
                MIN(current_a) AS min_current_a,
                MAX(current_a) AS max_current_a,
                AVG(power_w) AS avg_power_w,
                MIN(power_w) AS min_power_w,
                MAX(power_w) AS max_power_w
            FROM readings
            GROUP BY bucket, sensor_id
            WITH NO DATA
            """
        )
        op.execute(
            """
            SELECT add_continuous_aggregate_policy(
                'readings_day',
                start_offset => INTERVAL '30 days',
                end_offset => INTERVAL '1 day',
                schedule_interval => INTERVAL '1 day'
            )
            """
        )

        op.execute("CALL refresh_continuous_aggregate('readings_minute', NULL, NULL)")
        op.execute("CALL refresh_continuous_aggregate('readings_hour', NULL, NULL)")
        op.execute("CALL refresh_continuous_aggregate('readings_day', NULL, NULL)")

        op.execute(
            """
            ALTER TABLE readings SET (
                timescaledb.compress,
                timescaledb.compress_segmentby = 'sensor_id',
                timescaledb.compress_orderby = 'time DESC'
            )
            """
        )
        op.execute(
            """
            SELECT add_compression_policy('readings', INTERVAL '7 days', if_not_exists => true)
            """
        )
        op.execute(
            """
            SELECT add_retention_policy('readings', INTERVAL '365 days', if_not_exists => true)
            """
        )


def downgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute("SELECT remove_retention_policy('readings', if_exists => true)")
        op.execute("SELECT remove_compression_policy('readings', if_exists => true)")

        for name in ("readings_day", "readings_hour", "readings_minute"):
            _drop_aggregate(name)

        op.execute(
            """
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
            WITH NO DATA
            """
        )
        op.execute(
            """
            SELECT add_continuous_aggregate_policy(
                'readings_minute',
                start_offset => INTERVAL '3 hours',
                end_offset => INTERVAL '1 minute',
                schedule_interval => INTERVAL '1 minute'
            )
            """
        )

        op.execute(
            """
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
            WITH NO DATA
            """
        )
        op.execute(
            """
            SELECT add_continuous_aggregate_policy(
                'readings_hour',
                start_offset => INTERVAL '3 days',
                end_offset => INTERVAL '1 hour',
                schedule_interval => INTERVAL '1 hour'
            )
            """
        )

        op.execute(
            """
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
            WITH NO DATA
            """
        )
        op.execute(
            """
            SELECT add_continuous_aggregate_policy(
                'readings_day',
                start_offset => INTERVAL '30 days',
                end_offset => INTERVAL '1 day',
                schedule_interval => INTERVAL '1 day'
            )
            """
        )
