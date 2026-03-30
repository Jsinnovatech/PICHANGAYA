import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.config import settings

async def aplicar():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.connect() as conn:

        # 1. Limpiar ENUMs huérfanos
        await conn.execute(text("DROP TYPE IF EXISTS planenum CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS estadosuscripcionenum CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS tiponotificacionenum CASCADE"))
        print("✅ ENUMs limpiados")

        # 2. Crear tiponotificacionenum
        await conn.execute(text("""
            CREATE TYPE tiponotificacionenum AS ENUM (
                'suscripcion_voucher_recibido',
                'suscripcion_aprobada',
                'suscripcion_rechazada',
                'suscripcion_por_vencer',
                'reserva_nueva',
                'reserva_voucher_recibido',
                'reserva_confirmada',
                'reserva_rechazada'
            )
        """))
        print("✅ tiponotificacionenum creado")

        # 3. Cambiar columna tipo en notificaciones
        await conn.execute(text("""
            ALTER TABLE notificaciones
            ALTER COLUMN tipo TYPE tiponotificacionenum
            USING tipo::tiponotificacionenum
        """))
        print("✅ notificaciones.tipo actualizado")

        # 4. Agregar columna enviada_push
        await conn.execute(text("""
            ALTER TABLE notificaciones
            ADD COLUMN IF NOT EXISTS enviada_push BOOLEAN NOT NULL DEFAULT false
        """))
        print("✅ notificaciones.enviada_push agregado")

        # 5. Crear planenum
        await conn.execute(text("""
            CREATE TYPE planenum AS ENUM ('basico', 'premium')
        """))
        print("✅ planenum creado")

        # 6. Crear estadosuscripcionenum
        await conn.execute(text("""
            CREATE TYPE estadosuscripcionenum AS ENUM (
                'pendiente', 'activo', 'rechazado', 'vencido'
            )
        """))
        print("✅ estadosuscripcionenum creado")

        # 7. Crear tabla suscripciones
        await conn.execute(text("""
            CREATE TABLE IF NOT EXISTS suscripciones (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                admin_id UUID NOT NULL REFERENCES users(id),
                plan planenum NOT NULL,
                monto NUMERIC(8,2) NOT NULL,
                metodo_pago VARCHAR(20) NOT NULL,
                voucher_url VARCHAR(500),
                estado estadosuscripcionenum DEFAULT 'pendiente',
                fecha_pago TIMESTAMPTZ,
                fecha_vencimiento TIMESTAMPTZ,
                verificado_por UUID REFERENCES users(id),
                motivo_rechazo VARCHAR(300),
                created_at TIMESTAMPTZ DEFAULT now()
            )
        """))
        print("✅ tabla suscripciones creada")

        # 8. Marcar la migración como aplicada en Alembic
        await conn.execute(text("""
            UPDATE alembic_version
            SET version_num = '92c71b2d552c'
            WHERE version_num = 'f22c504046fe'
        """))
        print("✅ migración marcada como aplicada en Alembic")

        await conn.commit()
        print("\n🎉 TODO APLICADO CORRECTAMENTE")

    await engine.dispose()

asyncio.run(aplicar())