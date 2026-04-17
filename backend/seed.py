import asyncio
# asyncio es el módulo de Python para código asíncrono
# Lo necesitamos porque SQLAlchemy async requiere un event loop para ejecutarse

import uuid
# Para generar IDs únicos para cada registro

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
# create_async_engine → crea la conexión async a PostgreSQL
# AsyncSession → sesión para ejecutar queries de forma async

from sqlalchemy.orm import sessionmaker
# sessionmaker → fábrica que crea sesiones de base de datos

from app.core.config import settings
# Importa la configuración del .env para obtener la DATABASE_URL

from app.core.security import hash_password
# hash_password → convierte "cliente123" en "$2b$12$..." usando bcrypt
# NUNCA guardamos contraseñas en texto plano

from app.models.user import User, RolEnum
# El modelo User y el enum de roles

from app.models.local import Local
# El modelo Local para los complejos deportivos

from app.models.cancha import Cancha
# El modelo Cancha para las canchas individuales

from app.models.horario import HorarioDisponible
# El modelo para los horarios disponibles por cancha

from app.models.configuracion import Configuracion
# La configuración general del sistema


async def seed():
    # Esta función corre de forma asíncrona
    # async def → función que puede pausarse mientras espera operaciones lentas (BD)

    print("🌱 Iniciando seed de datos...")

    # Crear el engine de conexión a PostgreSQL
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    # echo=False → no muestra el SQL generado en la consola
    # echo=True → útil para debug, muestra cada query que se ejecuta

    # Crear la fábrica de sesiones
    AsyncSessionLocal = sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False
        # expire_on_commit=False → los objetos siguen accesibles después del commit
    )

    async with AsyncSessionLocal() as session:
    # async with → abre la sesión y la cierra automáticamente al terminar
    # Es como un try/finally automático

        # ══════════════════════════════════════════════
        # 1. USUARIOS
        # ══════════════════════════════════════════════
        print("👤 Creando usuarios...")

        super_admin = User(
            id=uuid.uuid4(),
            celular="900000000",           # celular del super admin
            nombre="Super Admin PichangaYa",
            password_hash=hash_password("superadmin123"),
            # hash_password convierte el texto en hash bcrypt seguro
            rol=RolEnum.super_admin,
            activo=True
        )

        admin_golazo = User(
            id=uuid.uuid4(),
            celular="911111111",           # celular del admin del primer complejo
            nombre="Admin El Golazo",
            password_hash=hash_password("admin123"),
            rol=RolEnum.admin,
            activo=True
        )

        admin_sport = User(
            id=uuid.uuid4(),
            celular="922222222",           # celular del admin del segundo complejo
            nombre="Admin Sport Comas",
            password_hash=hash_password("admin123"),
            rol=RolEnum.admin,
            activo=True
        )

        cliente1 = User(
            id=uuid.uuid4(),
            celular="999111222",           # datos de prueba igual al prototipo HTML
            nombre="Carlos Ramos",
            password_hash=hash_password("cliente123"),
            dni="45123456",
            rol=RolEnum.cliente,
            activo=True
        )

        cliente2 = User(
            id=uuid.uuid4(),
            celular="999333444",
            nombre="Luisa Torres",
            password_hash=hash_password("luisa123"),
            dni="12345678",
            rol=RolEnum.cliente,
            activo=True
        )

        # Agregar todos los usuarios a la sesión
        session.add_all([super_admin, admin_golazo, admin_sport, cliente1, cliente2])
        await session.flush()
        # flush() envía los datos a PostgreSQL sin hacer commit todavía
        # Necesario para obtener los IDs generados antes de usarlos en otras tablas

        print("   ✅ 5 usuarios creados")

        # ══════════════════════════════════════════════
        # 2. LOCALES — los mismos del prototipo HTML
        # ══════════════════════════════════════════════
        print("🏟️  Creando locales...")

        local1 = Local(
            id=uuid.uuid4(),
            admin_id=admin_golazo.id,
            nombre="Complejo Deportivo El Golazo",
            direccion="Av. Revolución 1250, Collique",
            lat=-11.9012,   # coordenadas GPS de Collique/Comas
            lng=-77.0520,
            telefono="01-5551234",
            descripcion="Complejo deportivo con 2 canchas de grass sintético",
            activo=True
        )

        local2 = Local(
            id=uuid.uuid4(),
            admin_id=admin_sport.id,
            nombre="Canchas Sport Comas",
            direccion="Jr. Los Pinos 456, Comas",
            lat=-11.9085,
            lng=-77.0461,
            telefono="01-5555678",
            descripcion="Canchas techadas disponibles todo el día",
            activo=True
        )

        local3 = Local(
            id=uuid.uuid4(),
            admin_id=admin_sport.id,
            nombre="Arena Fútbol Club",
            direccion="Av. Tupac Amaru Km 11.5, Collique",
            lat=-11.8950,
            lng=-77.0598,
            telefono="01-5559012",
            descripcion="Las mejores canchas de la zona norte de Lima",
            activo=True
        )

        session.add_all([local1, local2, local3])
        await session.flush()
        # flush aquí para tener los IDs de los locales
        # que necesitamos para crear las canchas

        print("   ✅ 3 locales creados")

        # ══════════════════════════════════════════════
        # 3. CANCHAS — las mismas del prototipo HTML
        # ══════════════════════════════════════════════
        print("⚽ Creando canchas...")

        canchas = [
            Cancha(
                id=uuid.uuid4(),
                local_id=local1.id,      # pertenece al Golazo
                nombre="Cancha A",
                capacidad=10,
                precio_hora=80.00,
                superficie="Gras Sintético",
                activa=True
            ),
            Cancha(
                id=uuid.uuid4(),
                local_id=local1.id,
                nombre="Cancha B",
                capacidad=10,
                precio_hora=90.00,
                superficie="Gras Sintético",
                activa=True
            ),
            Cancha(
                id=uuid.uuid4(),
                local_id=local2.id,      # pertenece a Sport Comas
                nombre="Cancha C",
                capacidad=14,
                precio_hora=70.00,
                superficie="Piso Madera",
                activa=True
            ),
            Cancha(
                id=uuid.uuid4(),
                local_id=local2.id,
                nombre="Cancha D",
                capacidad=12,
                precio_hora=85.00,
                superficie="Gras Sintético",
                activa=True
            ),
            Cancha(
                id=uuid.uuid4(),
                local_id=local3.id,      # pertenece a Arena FC
                nombre="Cancha E",
                capacidad=10,
                precio_hora=75.00,
                superficie="Gras Sintético",
                activa=True
            ),
            Cancha(
                id=uuid.uuid4(),
                local_id=local3.id,
                nombre="Cancha F",
                capacidad=8,
                precio_hora=65.00,
                superficie="Gras Sintético",
                activa=True
            ),
        ]

        session.add_all(canchas)
        await session.flush()
        # flush para tener los IDs de las canchas
        # que necesitamos para crear los horarios

        print("   ✅ 6 canchas creadas")

        # ══════════════════════════════════════════════
        # 4. HORARIOS — de 07:00 a 22:00 todos los días
        # ══════════════════════════════════════════════
        print("🕐 Creando horarios...")

        from datetime import time
        # time(7, 0) → 07:00
        # time(8, 0) → 08:00

        horarios_del_dia = [
            # (hora_inicio, hora_fin)
            (time(7, 0),  time(8, 0)),
            (time(8, 0),  time(9, 0)),
            (time(9, 0),  time(10, 0)),
            (time(10, 0), time(11, 0)),
            (time(11, 0), time(12, 0)),
            (time(12, 0), time(13, 0)),
            (time(13, 0), time(14, 0)),
            (time(14, 0), time(15, 0)),
            (time(15, 0), time(16, 0)),
            (time(16, 0), time(17, 0)),
            (time(17, 0), time(18, 0)),
            (time(18, 0), time(19, 0)),
            (time(19, 0), time(20, 0)),
            (time(20, 0), time(21, 0)),
            (time(21, 0), time(22, 0)),
        ]
        # 15 slots de 1 hora cada uno, de 7am a 10pm

        horarios_a_insertar = []

        for cancha in canchas:
        # Para cada cancha...
            for dia in range(7):
            # Para cada día de la semana (0=Lunes, 6=Domingo)...
                for inicio, fin in horarios_del_dia:
                # Para cada slot de hora...
                    horarios_a_insertar.append(
                        HorarioDisponible(
                            id=uuid.uuid4(),
                            cancha_id=cancha.id,
                            dia_semana=dia,
                            hora_inicio=inicio,
                            hora_fin=fin,
                            precio_override=None,
                            # None = usa el precio_hora de la cancha
                            # Se puede poner un precio diferente para horas pico
                            activo=True
                        )
                    )
        # Total: 6 canchas × 7 días × 15 slots = 630 horarios

        session.add_all(horarios_a_insertar)
        await session.flush()

        print(f"   ✅ {len(horarios_a_insertar)} horarios creados (6 canchas × 7 días × 15 slots)")

        # ══════════════════════════════════════════════
        # 5. CONFIGURACIÓN DEL SISTEMA
        # ══════════════════════════════════════════════
        print("⚙️  Creando configuración...")

        config = Configuracion(
            id=1,
            # id=1 siempre — esta tabla tiene una sola fila
            razon_social="PICHANGAYA SAC",
            ruc="20123456789",
            direccion_fiscal="Av. Revolución 1250, Collique, Lima",
            yape_numero="999-888-777",
            plin_numero="999-777-666",
            cuenta_bcp="215-12345678-0-01",
            cuenta_bbva="0011-0219-12345678-53",
            radio_busqueda_km=1.0
            # radio por defecto del mapa: 1km
        )

        session.add(config)

        # ══════════════════════════════════════════════
        # COMMIT FINAL — guarda todo en PostgreSQL
        # ══════════════════════════════════════════════
        await session.commit()
        # commit() hace permanentes todos los cambios
        # Si algo falla antes del commit, nada se guarda (transacción)

        print("")
        print("🎉 SEED COMPLETADO EXITOSAMENTE")
        print("─────────────────────────────────")
        print("👤 USUARIOS DE PRUEBA:")
        print("   Super Admin → celular: 900000000 / pass: superadmin123")
        print("   Admin Golazo → celular: 911111111 / pass: admin123")
        print("   Admin Sport  → celular: 922222222 / pass: admin123")
        print("   Cliente 1   → celular: 999111222 / pass: cliente123")
        print("   Cliente 2   → celular: 999333444 / pass: luisa123")
        print("─────────────────────────────────")
        print("🏟️  3 locales con 6 canchas y 630 horarios listos")

    await engine.dispose()
    # dispose() cierra todas las conexiones al terminar
    # Buena práctica para liberar recursos


# Punto de entrada del script
if __name__ == "__main__":
    asyncio.run(seed())
    # asyncio.run() → ejecuta la función async seed()
    # Sin esto no se puede llamar una función async desde código normal