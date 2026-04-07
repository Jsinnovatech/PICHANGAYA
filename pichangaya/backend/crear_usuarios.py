"""
Script para crear/actualizar usuarios de prueba en la BD.
Ejecutar desde la carpeta backend con el venv activo:
    python crear_usuarios.py
"""
import asyncio
import uuid
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select, text
from app.core.config import settings
from app.core.security import hash_password
from app.models.user import User, RolEnum


async def crear_usuarios():
    print("🔧 Conectando a la BD...")
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    usuarios = [
        {"celular": "900000000", "nombre": "Super Admin PichangaYa", "password": "superadmin123", "rol": RolEnum.super_admin},
        {"celular": "911111111", "nombre": "Admin El Golazo",         "password": "admin123",      "rol": RolEnum.admin},
        {"celular": "922222222", "nombre": "Admin Sport Comas",       "password": "admin123",      "rol": RolEnum.admin},
        {"celular": "999111222", "nombre": "Carlos Ramos",            "password": "cliente123",    "rol": RolEnum.cliente},
        {"celular": "999333444", "nombre": "Luisa Torres",            "password": "luisa123",      "rol": RolEnum.cliente},
    ]

    async with AsyncSessionLocal() as db:
        for u in usuarios:
            # Buscar si ya existe
            result = await db.execute(select(User).where(User.celular == u["celular"]))
            existing = result.scalar_one_or_none()

            nuevo_hash = hash_password(u["password"])

            if existing:
                # Actualizar contraseña y asegurarse que está activo
                existing.password_hash = nuevo_hash
                existing.activo = True
                existing.nombre = u["nombre"]
                existing.rol = u["rol"]
                print(f"  ✅ Actualizado: {u['celular']} ({u['rol'].value}) / {u['password']}")
            else:
                # Crear nuevo
                nuevo = User(
                    id=uuid.uuid4(),
                    celular=u["celular"],
                    nombre=u["nombre"],
                    password_hash=nuevo_hash,
                    rol=u["rol"],
                    activo=True,
                )
                db.add(nuevo)
                print(f"  ✅ Creado: {u['celular']} ({u['rol'].value}) / {u['password']}")

        await db.commit()
        print("\n🎉 Usuarios listos en la BD.")
        print("─────────────────────────────────────")
        print("  Super Admin → 900000000 / superadmin123")
        print("  Admin 1     → 911111111 / admin123")
        print("  Admin 2     → 922222222 / admin123")
        print("  Cliente 1   → 999111222 / cliente123")
        print("  Cliente 2   → 999333444 / luisa123")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(crear_usuarios())
