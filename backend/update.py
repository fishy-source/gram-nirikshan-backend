import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

from app.core.config import settings

async def main():
    engine = create_async_engine(settings.DATABASE_URL.replace("aiomysql", "asyncmy"))
    async with engine.begin() as conn:
        res = await conn.execute(text("UPDATE users SET mobile='7906276689' WHERE mobile='7906576689'"))
        print('Rows affected:', res.rowcount)

asyncio.run(main())
