import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.config import settings

async def fix():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.connect() as conn:
        await conn.execute(text("DROP TYPE IF EXISTS planenum CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS estadosuscripcionenum CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS tiponotificacionenum CASCADE"))
        await conn.commit()
        print("✅ ENUMs eliminados correctamente")
    await engine.dispose()

asyncio.run(fix())