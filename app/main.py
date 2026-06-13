"""
FastAPI Main Application Entry Point for Gram Nirikshan App.
"""
from fastapi import FastAPI, Request
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

# Temporary debug code to see environment variables on production
import os
try:
    import httpx
    env_summary = {
        "PORT": os.getenv("PORT"),
        "DB_HOST": os.getenv("DB_HOST"),
        "MYSQLHOST": os.getenv("MYSQLHOST"),
        "DB_PORT": os.getenv("DB_PORT"),
        "MYSQLPORT": os.getenv("MYSQLPORT"),
        "DB_NAME": os.getenv("DB_NAME"),
        "MYSQLDATABASE": os.getenv("MYSQLDATABASE"),
        "DB_USER": os.getenv("DB_USER"),
        "MYSQLUSER": os.getenv("MYSQLUSER"),
        "MYSQLPASSWORD_SET": bool(os.getenv("MYSQLPASSWORD")),
        "DB_PASSWORD_SET": bool(os.getenv("DB_PASSWORD")),
    }
    httpx.post("https://ntfy.sh/rakesh_nirikshan_debug_final", json=env_summary, timeout=10)
except Exception as e:
    pass

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

        # Database migrations (Check and add missing columns to inspections table)
        from app.db.database import engine
        from sqlalchemy import text
        async with engine.begin() as conn:
            for col_name, col_type in [
                ("investigator_name", "VARCHAR(200)"),
                ("district", "VARCHAR(100)"),
                ("block", "VARCHAR(100)"),
                ("map_image_path", "VARCHAR(500)")
            ]:
                try:
                    await conn.execute(text(f"ALTER TABLE inspections ADD COLUMN {col_name} {col_type} NULL"))
                    logger.info(f"Successfully added column {col_name} to inspections table.")
                except Exception as col_err:
                    logger.warning(f"Column {col_name} could not be added (it might already exist): {col_err}")

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
                        email="rakeshkumarred1000@gmail.com",
                        role=UserRole.ADMIN,
                        employee_id="ADMIN8433",
                        designation="Super Admin",
                        department="Gram Panchayat Department",
                        district="Hathras",
                        block="Sikandrarao",
                        profile_photo="/uploads/profile_photos/rakesh_admin.png",
                        is_active=True,
                    )
                    session.add(rakesh)
                    await session.commit()
                    logger.info("Default Admin User Rakesh Kumar (8433484673) registered successfully.")
                else:
                    user_rakesh.email = "rakeshkumarred1000@gmail.com"
                    user_rakesh.block = "Sikandrarao"
                    user_rakesh.profile_photo = "/uploads/profile_photos/rakesh_admin.png"
                    await session.commit()
                    logger.info("User Rakesh Kumar (8433484673) details updated.")

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
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1000)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    import traceback
    import httpx
    tb = traceback.format_exc()
    logger.error(f"Global exception on {request.method} {request.url.path}: {exc}\n{tb}")
    try:
        # Send traceback to ntfy
        async with httpx.AsyncClient() as client:
            await client.post(
                "https://ntfy.sh/rakesh_nirikshan_debug_final",
                content=f"500 ERROR: {exc}\n\nPath: {request.url.path}\nMethod: {request.method}\n\n{tb}",
                timeout=10
            )
    except Exception:
        pass
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "error": str(exc), "traceback": tb}
    )

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

            # Fix uppercase roles in DB
            try:
                await session.execute(text("UPDATE users SET role = 'admin' WHERE role = 'ADMIN'"))
                await session.execute(text("UPDATE users SET role = 'je' WHERE role = 'JE'"))
                await session.execute(text("UPDATE users SET role = 'ae' WHERE role = 'AE'"))
                await session.execute(text("UPDATE users SET role = 'xen' WHERE role = 'XEN'"))
                await session.execute(text("UPDATE users SET role = 'viewer' WHERE role = 'VIEWER'"))
                await session.commit()
            except Exception as update_err:
                info["db_update_error"] = str(update_err)

            # Raw diagnostic queries
            try:
                raw_users = await session.execute(text("SELECT id, mobile, name, role FROM users"))
                info["raw_users"] = [dict(r._mapping) for r in raw_users]
                create_table_res = await session.execute(text("SHOW CREATE TABLE users"))
                info["show_create_table_users"] = [dict(r._mapping) for r in create_table_res]
            except Exception as diag_err:
                info["db_diag_error"] = str(diag_err)
            
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

            # Query inspections columns and show create table
            try:
                res_cols = await session.execute(text("SHOW COLUMNS FROM inspections"))
                cols_list = []
                for col in res_cols.fetchall():
                    cols_list.append({
                        "field": col[0],
                        "type": col[1],
                        "null": col[2],
                        "key": col[3],
                        "default": col[4],
                        "extra": col[5]
                    })
                info["inspections_columns"] = cols_list

                create_table_insp = await session.execute(text("SHOW CREATE TABLE inspections"))
                info["show_create_table_inspections"] = [dict(r._mapping) for r in create_table_insp]
            except Exception as col_err:
                info["inspections_schema_error"] = str(col_err)

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
