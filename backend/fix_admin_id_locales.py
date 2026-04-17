"""
fix_admin_id_locales.py
-----------------------
Asigna admin_id a los locales existentes que quedaron con NULL
después de la migración a2b3c4d5e6f7.

Cómo usarlo:
  cd backend
  venv\\Scripts\\activate
  python fix_admin_id_locales.py

El script lista los locales sin admin_id y los admins disponibles,
y te pide que asignes manualmente cada local a su admin.
"""
import asyncio
from sqlalchemy import select, update
from app.core.database import AsyncSessionLocal
from app.models.local import Local
from app.models.user import User, RolEnum


async def main():
    async with AsyncSessionLocal() as db:
        # Locales sin admin_id
        locales_sin_admin = (await db.execute(
            select(Local).where(Local.admin_id == None).order_by(Local.nombre)
        )).scalars().all()

        if not locales_sin_admin:
            print("✅ Todos los locales ya tienen admin_id asignado.")
            return

        # Admins disponibles
        admins = (await db.execute(
            select(User).where(User.rol == RolEnum.admin, User.activo == True).order_by(User.nombre)
        )).scalars().all()

        print(f"\n📋 {len(locales_sin_admin)} local(es) sin admin_id:\n")
        for i, l in enumerate(locales_sin_admin):
            print(f"  [{i}] {l.nombre} — {l.direccion}")

        print(f"\n👤 Admins disponibles:\n")
        for i, a in enumerate(admins):
            print(f"  [{i}] {a.nombre} ({a.celular})")

        print("\nAsigna cada local a un admin (escribe el índice del admin):\n")
        for local in locales_sin_admin:
            while True:
                try:
                    idx = int(input(f"  '{local.nombre}' → admin índice: "))
                    if 0 <= idx < len(admins):
                        local.admin_id = admins[idx].id
                        break
                    print("  Índice inválido.")
                except ValueError:
                    print("  Escribe un número.")

        await db.commit()
        print("\n✅ admin_id asignado a todos los locales.")


if __name__ == "__main__":
    asyncio.run(main())
