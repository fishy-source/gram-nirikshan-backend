"""
FastAPI Main Application Entry Point for Gram Nirikshan App.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from pathlib import Path

from app.core.config import settings
from app.db.database import create_tables
from app.api.routes.auth import router as auth_router
from app.api.routes.inspections import router as inspections_router
from app.api.routes.photos import router as photos_router
from app.api.routes.reports import router as reports_router
from app.api.routes.ai import router as ai_router
from app.api.routes.dashboard import router as dashboard_router, user_router, panchayat_router

logging.basicConfig(level=logging.INFO if settings.DEBUG else logging.WARNING)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup/shutdown events."""
    logger.info("Starting Gram Nirikshan API...")
    await create_tables()
    logger.info("Database tables created/verified.")

    # Create upload directories
    for subdir in ["photos", "documents", "reports", "photos/thumbnails"]:
        Path(settings.UPLOAD_DIR, subdir).mkdir(parents=True, exist_ok=True)

    yield
    logger.info("Shutting down Gram Nirikshan API.")


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="""
## Gram Nirikshan App - Backend API

A complete backend for Gram Panchayat inspection management.

### Features:
- 🔐 Mobile OTP Authentication
- 👥 Role-Based Access Control (Admin/JE/AE/XEN/Viewer)
- 🔍 Inspection Management with Auto-ID
- 📸 Watermarked Photo Upload
- 📍 GPS Check-in/Check-out
- 📋 PDF Report Generation
- 🤖 Gemini AI Assistant
- ✅ JE-AE-XEN Approval Workflow
- 📊 Dashboard Analytics
    """,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ─── Middleware ────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1000)

# ─── Static File Serving ───────────────────────────────────────────────────────

uploads_path = Path(settings.UPLOAD_DIR)
uploads_path.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(uploads_path)), name="uploads")

# ─── Routes ────────────────────────────────────────────────────────────────────

prefix = settings.API_PREFIX

app.include_router(auth_router, prefix=prefix)
app.include_router(user_router, prefix=prefix)
app.include_router(panchayat_router, prefix=prefix)
app.include_router(inspections_router, prefix=prefix)
app.include_router(photos_router, prefix=prefix)
app.include_router(reports_router, prefix=prefix)
app.include_router(ai_router, prefix=prefix)
app.include_router(dashboard_router, prefix=prefix)


# ─── Health Check ──────────────────────────────────────────────────────────────

@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "app": settings.APP_NAME, "version": settings.APP_VERSION}


@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Welcome to Gram Nirikshan API",
        "docs": "/docs",
        "version": settings.APP_VERSION
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=settings.DEBUG)
