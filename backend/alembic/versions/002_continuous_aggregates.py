"""Continuous aggregates for readings time-series charts."""

from typing import Sequence, Union

from alembic import op

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.get_context().autocommit_block():
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

        op.execute("CALL refresh_continuous_aggregate('readings_minute', NULL, NULL)")
        op.execute("CALL refresh_continuous_aggregate('readings_hour', NULL, NULL)")
        op.execute("CALL refresh_continuous_aggregate('readings_day', NULL, NULL)")


def downgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute(
            "SELECT remove_continuous_aggregate_policy('readings_day', if_exists => true)"
        )
        op.execute("DROP MATERIALIZED VIEW IF EXISTS readings_day")

        op.execute(
            "SELECT remove_continuous_aggregate_policy('readings_hour', if_exists => true)"
        )
        op.execute("DROP MATERIALIZED VIEW IF EXISTS readings_hour")

        op.execute(
            "SELECT remove_continuous_aggregate_policy('readings_minute', if_exists => true)"
        )
        op.execute("DROP MATERIALIZED VIEW IF EXISTS readings_minute")
