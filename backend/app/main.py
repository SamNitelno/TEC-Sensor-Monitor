from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.db.session import async_session_factory
from app.routers import auth, ingest, readings, sensors, sites, workshops
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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(ingest.router, prefix="/api/v1")
app.include_router(sensors.router, prefix="/api/v1")
app.include_router(readings.router, prefix="/api/v1")
app.include_router(sites.router, prefix="/api/v1")
app.include_router(workshops.router, prefix="/api/v1")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
