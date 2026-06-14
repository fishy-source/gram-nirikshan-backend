"""
Database connection module for Gram Nirikshan App.
Uses SQLAlchemy with MySQL (asyncmy driver).
"""
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from app.core.config import settings

# Async MySQL engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=False,
    pool_recycle=3600,
)

# Session factory
AsyncSessionLocal = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Base class for all database models."""
    pass


async def get_db():
    """Dependency to get database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def create_tables():
    """Create all database tables."""
    from sqlalchemy import text
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        
        # Check and add new columns to inspections table if they don't exist
        try:
            # Modify role column in users to VARCHAR instead of ENUM to support new roles
            await conn.execute(text("ALTER TABLE users MODIFY COLUMN role VARCHAR(50) NOT NULL DEFAULT 'inspector'"))
            
            # Check aadhar_number in users
            res = await conn.execute(text("SHOW COLUMNS FROM users LIKE 'aadhar_number'"))
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE users ADD COLUMN aadhar_number VARCHAR(12) NULL UNIQUE"))
                
            # Check investigator_name
            res = await conn.execute(text("SHOW COLUMNS FROM inspections LIKE 'investigator_name'"))
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE inspections ADD COLUMN investigator_name VARCHAR(200) NULL"))
            
            # Check district
            res = await conn.execute(text("SHOW COLUMNS FROM inspections LIKE 'district'"))
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE inspections ADD COLUMN district VARCHAR(100) NULL"))
                
            # Check block
            res = await conn.execute(text("SHOW COLUMNS FROM inspections LIKE 'block'"))
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE inspections ADD COLUMN block VARCHAR(100) NULL"))
                
            # Check map_image_path
            res = await conn.execute(text("SHOW COLUMNS FROM inspections LIKE 'map_image_path'"))
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE inspections ADD COLUMN map_image_path VARCHAR(500) NULL"))
        except Exception as e:
            print(f"Error checking/altering inspections table schema: {e}")
