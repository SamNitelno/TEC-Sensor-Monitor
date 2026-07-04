from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.downtime_event import DowntimeType
from app.models.sensor import Sensor
from app.models.user import User
from app.models.user_notification import UserNotification
from app.repositories import (
    notification_repository,
    site_repository,
    workshop_repository,
)
from app.schemas.notification import (
    NotificationAckResponse,
    NotificationCountResponse,
    NotificationItem,
)


def format_duration_ru(seconds: float) -> str:
    total = max(0, int(seconds))
    if total < 60:
        return f"{total} сек"
    minutes = total // 60
    if minutes < 60:
        return f"{minutes} мин"
    hours = minutes // 60
    minutes %= 60
    if hours < 24:
        return f"{hours} ч {minutes} мин" if minutes else f"{hours} ч"
    days = hours // 24
    hours %= 24
    return f"{days} д {hours} ч" if hours else f"{days} д"


async def _workshop_name_for_sensor(session: AsyncSession, sensor: Sensor) -> str:
    if sensor.site_id is None:
        return "—"
    site = await site_repository.get_by_id(session, sensor.site_id)
    if site is None:
        return "—"
    workshop = await workshop_repository.get_by_id(session, site.workshop_id)
    return workshop.name if workshop is not None else "—"


async def notifications_enabled_for_sensor(
    session: AsyncSession,
    sensor: Sensor,
) -> bool:
    """Per-sensor flag is authoritative; workshop/site toggles only bulk-update sensors."""
    return sensor.notifications_enabled


async def notify_downtime_event(
    session: AsyncSession,
    *,
    sensor: Sensor,
    event_type: DowntimeType,
    started_at: datetime,
) -> None:
    if not await notifications_enabled_for_sensor(session, sensor):
        return

    workshop_name = await _workshop_name_for_sensor(session, sensor)
    started = started_at if started_at.tzinfo else started_at.replace(tzinfo=UTC)
    elapsed = (datetime.now(UTC) - started.astimezone(UTC)).total_seconds()
    duration = format_duration_ru(elapsed)

    if event_type == DowntimeType.offline:
        message = (
            f"«{sensor.name}» · цех «{workshop_name}» · offline · с начала {duration}"
        )
        kind = "sensor_offline"
    else:
        message = (
            f"«{sensor.name}» · цех «{workshop_name}» · простой · с начала {duration}"
        )
        kind = "sensor_idle"

    result = await session.execute(
        select(User).where(User.is_active.is_(True))
    )
    users = list(result.scalars().all())
    for user in users:
        await notification_repository.create(
            session,
            user_id=user.id,
            message=message,
            kind=kind,
        )


async def list_unread(session: AsyncSession, user: User) -> list[NotificationItem]:
    rows = await notification_repository.list_unread_for_user(session, user.id)
    return [
        NotificationItem(
            id=row.id,
            message=row.message,
            kind=row.kind,
            created_at=row.created_at,
        )
        for row in rows
    ]


async def unread_count(session: AsyncSession, user: User) -> NotificationCountResponse:
    count = await notification_repository.count_unread_for_user(session, user.id)
    return NotificationCountResponse(count=count)


async def acknowledge(
    session: AsyncSession,
    user: User,
    notification_id: int,
) -> NotificationAckResponse:
    from fastapi import HTTPException, status

    result = await session.execute(
        select(UserNotification).where(
            UserNotification.id == notification_id,
            UserNotification.user_id == user.id,
        )
    )
    notification = result.scalar_one_or_none()
    if notification is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")

    await notification_repository.mark_read(session, notification)
    await session.commit()
    return NotificationAckResponse(id=notification.id)


async def acknowledge_all(session: AsyncSession, user: User) -> int:
    rows = await notification_repository.list_unread_for_user(session, user.id, limit=500)
    for row in rows:
        await notification_repository.mark_read(session, row)
    await session.commit()
    return len(rows)


async def notify_role_change(
    session: AsyncSession,
    *,
    target: User,
    actor_login: str,
    promoted: bool,
) -> None:
    if promoted:
        message = f"{actor_login} повысил вас до уровня администратора"
        kind = "role_promoted"
    else:
        message = f"{actor_login} понизил вас до уровня наблюдателя"
        kind = "role_demoted"
    await notification_repository.create(
        session,
        user_id=target.id,
        message=message,
        kind=kind,
    )
