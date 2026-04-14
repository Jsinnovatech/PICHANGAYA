"""
fix_notif_enum.py
=================
Agrega 'reserva_cancelada_por_cliente' al enum tiponotificacionenum en PostgreSQL.
Este valor es necesario para que la cancelación de reservas funcione correctamente.

Uso:
    python fix_notif_enum.py
"""
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.config import settings


async def fix():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.connect() as conn:

        # 1. Agregar reserva_cancelada_por_cliente al enum
        await conn.execute(text("""
            ALTER TYPE tiponotificacionenum
            ADD VALUE IF NOT EXISTS 'reserva_cancelada_por_cliente';
        """))
        print("✅ 'reserva_cancelada_por_cliente' agregado al enum tiponotificacionenum")

        # 2. Actualizar version de Alembic para reflejar que ambas ramas están aplicadas
        # (merge de 4f4f8043c1a6 y a1b2c3d4e5f6)
        result = await conn.execute(text("SELECT version_num FROM alembic_version"))
        version_actual = result.scalar()
        print(f"   Versión Alembic actual: {version_actual}")

        if version_actual in ('4f4f8043c1a6', '92c71b2d552c'):
            await conn.execute(text("""
                UPDATE alembic_version
                SET version_num = 'merge_heads_final'
            """))
            print("✅ Alembic version actualizada a 'merge_heads_final'")

        await conn.commit()
        print("\n🎉 Fix aplicado correctamente. Reinicia el backend.")

    await engine.dispose()


asyncio.run(fix())
