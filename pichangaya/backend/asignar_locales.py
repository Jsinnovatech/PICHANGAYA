"""
Script para asignar cada local a su admin correspondiente.
Ejecutar desde la carpeta backend con venv activo:
    python asignar_locales.py
"""
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select
from app.core.config import settings
from app.models.local import Local
from app.models.user import User


async def asignar():
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    S = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    # Mapa: celular del admin → nombre parcial de su local
    asignaciones = [
        ("911111111", "Golazo"),       # Admin El Golazo → Complejo El Golazo
        ("922222222", "Sport Comas"),  # Admin Sport Comas → Canchas Sport Comas
    ]

    async with S() as db:
        for celular, nombre_local in asignaciones:
            # Buscar admin
            admin_r = await db.execute(
                select(User).where(User.celular == celular)
            )
            admin = admin_r.scalar_one_or_none()

            # Buscar local
            local_r = await db.execute(
                select(Local).where(Local.nombre.ilike(f'%{nombre_local}%'))
            )
            local = local_r.scalar_one_or_none()

            if admin and local:
                local.admin_id = admin.id
                print(f"  ✅ '{local.nombre}' → asignado a '{admin.nombre}'")
            elif not admin:
                print(f"  ❌ No se encontró admin con celular {celular}")
            elif not local:
                print(f"  ❌ No se encontró local con nombre '{nombre_local}'")

        await db.commit()
        print("\n🎉 Locales asignados correctamente.")
        print("─────────────────────────────────────")
        print("  Admin 911111111 → Complejo El Golazo")
        print("  Admin 922222222 → Canchas Sport Comas")
        print("\nNota: Arena Fútbol Club no tiene admin asignado.")
        print("Puedes asignarlo editando este script.")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(asignar())
