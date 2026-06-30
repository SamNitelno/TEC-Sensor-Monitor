from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.db.session import async_session_factory
from app.routers import ingest
from app.services.admin_bootstrap import ensure_admin_user


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with async_session_factory() as session:
        await ensure_admin_user(session)
    yield


app = FastAPI(
    title="TEC Sensor Monitor",
    description="Internal sensor downtime monitoring for Tomsk Electronic Company",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(ingest.router, prefix="/api/v1")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
