"""
⚠️ DEPRECATION NOTICE: This file is the application definition only.
DO NOT run this file directly.

✅ Use the standardized entry point instead:
   python run.py

Map Backend - FastAPI Application
Service for static map images and elevation correction.
"""

import logging
from contextlib import asynccontextmanager
import os
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Add backend directory to path for shared imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from config import get_config
from routes.elevation import router as elevation_router
from routes.maps import router as maps_router
from services.storage_backend import get_storage_health, initialize_storage_backend
from shared.rate_limiter import add_redis_rate_limiter

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

config = get_config()


def _get_rate_limit_policies() -> list[dict]:
    """Route-level default policies. Specific routes should come first."""
    default_policies = [
        {
            "path_pattern": "/api/maps/static/image",
            "methods": ["POST"],
            "limit": 10,
            "window_seconds": 60,
        },
        {
            "path_pattern": "/api/maps/dynamic/html",
            "methods": ["POST"],
            "limit": 10,
            "window_seconds": 60,
        },
        {
            "path_pattern": "/api/elevation/lookup",
            "methods": ["POST"],
            "limit": 30,
            "window_seconds": 60,
        },
        {
            "path_pattern": "/api/elevation/point",
            "methods": ["GET"],
            "limit": 60,
            "window_seconds": 60,
        },
        {
            "path_pattern": "/api/maps/*",
            "methods": ["GET", "POST"],
            "limit": 20,
            "window_seconds": 60,
        },
    ]

    if config.RATE_LIMIT_POLICIES:
        return config.RATE_LIMIT_POLICIES

    return default_policies


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown lifecycle."""
    logger.info(f"Starting Map Backend on {config.HOST}:{config.PORT}")
    logger.info(f"Environment: {config.FASTAPI_ENV} | Debug: {config.DEBUG}")

    # Initialize configured map storage backend once at startup.
    try:
        initialize_storage_backend()
        logger.info("✅ Storage backend initialized successfully")
    except Exception as e:
        logger.error(f"❌ Failed to initialize storage backend: {e}")
        raise

    yield

    logger.info("Shutting down Map Backend")


app = FastAPI(
    title="Map Backend API",
    description="Service for static map images and elevation correction",
    version="1.0.0",
    lifespan=lifespan,
)

if config.RATE_LIMIT_ENABLED:
    add_redis_rate_limiter(
        app,
        redis_url=config.RATE_LIMIT_REDIS_URL,
        namespace=config.RATE_LIMIT_NAMESPACE,
        policies=_get_rate_limit_policies(),
        default_limit=config.RATE_LIMIT_DEFAULT_LIMIT,
        default_window_seconds=config.RATE_LIMIT_DEFAULT_WINDOW_SECONDS,
        fail_open=config.RATE_LIMIT_FAIL_OPEN,
    )
    logger.info(
        "Redis rate limiter enabled (namespace=%s, redis=%s)",
        config.RATE_LIMIT_NAMESPACE,
        config.RATE_LIMIT_REDIS_URL,
    )
else:
    logger.warning("Redis rate limiter disabled via RATE_LIMIT_ENABLED=false")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Routers
app.include_router(maps_router)
app.include_router(elevation_router)


@app.get("/")
def root():
    return {"service": "Map Backend", "status": "running", "version": "1.0.0"}


@app.get("/health")
def health():
    storage = get_storage_health()
    status = "healthy" if storage.get("status") == "healthy" else "degraded"
    return {
        "status": status,
        "service": "map-backend",
        "storage": storage,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=config.HOST,
        port=config.PORT,
        reload=config.DEBUG,
        log_level="info",
    )
