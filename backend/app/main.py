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
    app.state.startup_error = None
    app.state.startup_traceback = None
    try:
        await create_tables()
        logger.info("Database tables created/verified.")

        # Ensure upload directories exist
        for subdir in ["photos", "documents", "reports", "photos/thumbnails"]:
            Path(settings.UPLOAD_DIR, subdir).mkdir(parents=True, exist_ok=True)

        # Seed default users and panchayats
        from app.db.database import AsyncSessionLocal
        from app.models.models import User, UserRole, Panchayat
        from sqlalchemy import select
        import uuid

        async with AsyncSessionLocal() as session:
            try:
                # 1. Seed Rakesh Kumar (Admin)
                res = await session.execute(select(User).where(User.mobile == "8433484673"))
                user_rakesh = res.scalar_one_or_none()
                if not user_rakesh:
                    rakesh = User(
                        id=str(uuid.uuid4()),
                        mobile="8433484673",
                        name="Rakesh Kumar",
                        name_hindi="राकेश कुमार",
                        email="rakesh@example.com",
                        role=UserRole.ADMIN,
                        employee_id="ADMIN8433",
                        designation="Super Admin",
                        department="Gram Panchayat Department",
                        district="Hathras",
                        block="Hathras",
                        is_active=True,
                    )
                    session.add(rakesh)
                    await session.commit()
                    logger.info("Default Admin User Rakesh Kumar (8433484673) registered successfully.")
                else:
                    logger.info("User Rakesh Kumar (8433484673) already registered.")

                # 2. Seed System Administrator (Admin)
                res2 = await session.execute(select(User).where(User.mobile == "9999999999"))
                user_test = res2.scalar_one_or_none()
                if not user_test:
                    test_user = User(
                        id=str(uuid.uuid4()),
                        mobile="9999999999",
                        name="System Administrator",
                        name_hindi="सिस्टम प्रशासक",
                        email="admin@gramnirikshan.in",
                        role=UserRole.ADMIN,
                        employee_id="ADMIN001",
                        designation="System Admin",
                        department="Gram Panchayat Department",
                        district="Lucknow",
                        block="Mohanlalganj",
                        is_active=True,
                    )
                    session.add(test_user)
                    await session.commit()
                    logger.info("System Admin (9999999999) registered successfully.")

                # 3. Seed Sample Panchayat
                res_panchayat = await session.execute(select(Panchayat).where(Panchayat.code == "GP001"))
                existing_panchayat = res_panchayat.scalar_one_or_none()
                if not existing_panchayat:
                    panchayat = Panchayat(
                        id=str(uuid.uuid4()),
                        name="Rampur Gram Panchayat",
                        name_hindi="रामपुर ग्राम पंचायत",
                        code="GP001",
                        district="Lucknow",
                        block="Mohanlalganj",
                        village="Rampur",
                        latitude=26.8467,
                        longitude=80.9462,
                        is_active=True
                    )
                    session.add(panchayat)
                    await session.commit()
                    logger.info("Sample Panchayat GP001 registered successfully.")

            except Exception as e:
                logger.error(f"Error seeding database: {e}")
    except Exception as err:
        import traceback
        import httpx
        tb = traceback.format_exc()
        logger.error(f"Error during lifespan startup: {err}")
        app.state.startup_error = str(err)
        app.state.startup_traceback = tb
        try:
            httpx.post("https://ntfy.sh/rakesh_nirikshan_debug_final", content=f"STARTUP ERROR: {err}\n\n{tb}", timeout=10)
        except Exception:
            pass

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


# Trigger redeployment to see if DB connection succeeded
@app.get("/debug", tags=["Health"])
async def debug_endpoint(seed: bool = False):
    import traceback
    import os
    from app.db.database import AsyncSessionLocal
    from app.models.models import User, Panchayat, UserRole
    from sqlalchemy import select
    import uuid

    info = {}
    info["startup_error"] = getattr(app.state, "startup_error", None)
    info["startup_traceback"] = getattr(app.state, "startup_traceback", None)
    info["env"] = {
        "DB_HOST": os.getenv("DB_HOST") or os.getenv("MYSQLHOST"),
        "DB_PORT": os.getenv("DB_PORT") or os.getenv("MYSQLPORT"),
        "DB_NAME": os.getenv("DB_NAME") or os.getenv("MYSQLDATABASE"),
        "DB_USER": os.getenv("DB_USER") or os.getenv("MYSQLUSER"),
        "DB_PASSWORD_SET": bool(os.getenv("DB_PASSWORD") or os.getenv("MYSQLPASSWORD") or settings.DB_PASSWORD),
    }

    # Test DB Connection and list data
    try:
        async with AsyncSessionLocal() as session:
            from sqlalchemy.sql import text
            res = await session.execute(text("SELECT 1"))
            info["db_connection"] = "Success"
            info["db_test_query"] = res.scalar()
            
            # Seeding if requested
            if seed:
                seed_logs = []
                # 1. Seed Rakesh Kumar
                res_u1 = await session.execute(select(User).where(User.mobile == "8433484673"))
                user_rakesh = res_u1.scalar_one_or_none()
                if not user_rakesh:
                    rakesh = User(
                        id=str(uuid.uuid4()),
                        mobile="8433484673",
                        name="Rakesh Kumar",
                        name_hindi="राकेश कुमार",
                        email="rakesh@example.com",
                        role=UserRole.ADMIN,
                        employee_id="ADMIN8433",
                        designation="Super Admin",
                        department="Gram Panchayat Department",
                        district="Hathras",
                        block="Hathras",
                        is_active=True,
                    )
                    session.add(rakesh)
                    await session.commit()
                    seed_logs.append("Seeded Rakesh Kumar successfully")
                else:
                    seed_logs.append("Rakesh Kumar already exists")

                # 2. Seed System Administrator
                res_u2 = await session.execute(select(User).where(User.mobile == "9999999999"))
                user_test = res_u2.scalar_one_or_none()
                if not user_test:
                    test_user = User(
                        id=str(uuid.uuid4()),
                        mobile="9999999999",
                        name="System Administrator",
                        name_hindi="सिस्टम प्रशासक",
                        email="admin@gramnirikshan.in",
                        role=UserRole.ADMIN,
                        employee_id="ADMIN001",
                        designation="System Admin",
                        department="Gram Panchayat Department",
                        district="Lucknow",
                        block="Mohanlalganj",
                        is_active=True,
                    )
                    session.add(test_user)
                    await session.commit()
                    seed_logs.append("Seeded System Administrator successfully")
                else:
                    seed_logs.append("System Administrator already exists")

                # 3. Seed Sample Panchayat
                res_p = await session.execute(select(Panchayat).where(Panchayat.code == "GP001"))
                existing_panchayat = res_p.scalar_one_or_none()
                if not existing_panchayat:
                    panchayat = Panchayat(
                        id=str(uuid.uuid4()),
                        name="Rampur Gram Panchayat",
                        name_hindi="रामपुर ग्राम पंचायत",
                        code="GP001",
                        district="Lucknow",
                        block="Mohanlalganj",
                        village="Rampur",
                        latitude=26.8467,
                        longitude=80.9462,
                        is_active=True
                    )
                    session.add(panchayat)
                    await session.commit()
                    seed_logs.append("Seeded Panchayat GP001 successfully")
                else:
                    seed_logs.append("Panchayat GP001 already exists")
                
                info["seed_result"] = seed_logs

            # Query users
            res_users = await session.execute(select(User))
            users_list = []
            for u in res_users.scalars():
                users_list.append({
                    "id": u.id,
                    "mobile": u.mobile,
                    "name": u.name,
                    "role": u.role.value if u.role else None,
                    "is_active": u.is_active
                })
            info["users"] = users_list
            
            # Query panchayats
            res_panchayats = await session.execute(select(Panchayat))
            panchayats_list = []
            for p in res_panchayats.scalars():
                panchayats_list.append({
                    "id": p.id,
                    "code": p.code,
                    "name": p.name
                })
            info["panchayats"] = panchayats_list
    except Exception as e:
        info["db_connection"] = f"Failed: {str(e)}"
        info["db_traceback"] = traceback.format_exc()

    return info



@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Welcome to Gram Nirikshan API",
        "docs": "/docs",
        "version": settings.APP_VERSION
    }


if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=settings.DEBUG)
