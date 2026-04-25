"""
Script para crear la tabla bloqueos_horario en Railway.
Ejecutar una sola vez:
    cd backend && venv\Scripts\activate && python crear_tabla_bloqueos.py
"""
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from app.core.config import settings
from app.core.database import Base
from app.models.bloqueo import BloqueoHorario  # noqa: F401 — registra el modelo


async def main():
    engine = create_async_engine(settings.DATABASE_URL, echo=True)
    async with engine.begin() as conn:
        await conn.run_sync(
            Base.metadata.create_all,
            tables=[BloqueoHorario.__table__]
        )
    await engine.dispose()
    print("\n✅ Tabla bloqueos_horario creada correctamente.")


if __name__ == "__main__":
    asyncio.run(main())
