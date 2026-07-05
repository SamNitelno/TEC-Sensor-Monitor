from contextlib import asynccontextmanager
import asyncio

import structlog
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.core.config import settings
from app.core.logging_config import configure_logging
from app.core.prod_guard import validate_production_settings
from app.core.rate_limit import limiter
from app.db.session import async_session_factory
from app.routers import (
    auth,
    downtime,
    ingest,
    notifications,
    readings,
    sensors,
    sites,
    users,
    workshops,
    ws,
)
from app.services.admin_bootstrap import ensure_admin_user
from app.services.downtime_detection_service import downtime_worker_loop
from app.services.mqtt_subscriber import mqtt_subscriber_loop
from app.services.offline_sensor_service import offline_watchdog_loop

validate_production_settings(settings)
configure_logging(json_logs=settings.json_logs, log_level=settings.log_level)
logger = structlog.get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with async_session_factory() as session:
        await ensure_admin_user(session)

    background_tasks = [
        asyncio.create_task(downtime_worker_loop()),
        asyncio.create_task(offline_watchdog_loop()),
    ]
    if settings.mqtt_enabled:
        background_tasks.append(asyncio.create_task(mqtt_subscriber_loop()))

    logger.info(
        "app_started",
        app_env=settings.app_env,
        mqtt_enabled=settings.mqtt_enabled,
        allow_public_registration=settings.allow_public_registration,
    )
    try:
        yield
    finally:
        for task in background_tasks:
            task.cancel()
        for task in background_tasks:
            try:
                await task
            except asyncio.CancelledError:
                pass
        logger.info("app_stopped")


_docs_url = None if settings.is_production else "/docs"
_redoc_url = None if settings.is_production else "/redoc"

app = FastAPI(
    title="TEC Sensor Monitor",
    description="Internal sensor downtime monitoring for Tomsk Electronic Company",
    version="0.2.0",
    lifespan=lifespan,
    docs_url=_docs_url,
    redoc_url=_redoc_url,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

_cors_origins = settings.cors_origin_list
if settings.is_production and not _cors_origins:
    _cors_origins = [settings.api_public_base_url.rstrip("/")]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins if _cors_origins else [settings.api_public_base_url.rstrip("/")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(notifications.router, prefix="/api/v1")
app.include_router(ingest.router, prefix="/api/v1")
app.include_router(sensors.router, prefix="/api/v1")
app.include_router(readings.router, prefix="/api/v1")
app.include_router(downtime.router, prefix="/api/v1")
app.include_router(sites.router, prefix="/api/v1")
app.include_router(workshops.router, prefix="/api/v1")
app.include_router(ws.router)


@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    log = logger.bind(method=request.method, path=request.url.path)
    response = await call_next(request)
    log.info("http_request", status_code=response.status_code)
    return response


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
