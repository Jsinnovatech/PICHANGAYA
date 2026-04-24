# add_horas_nocturnas.py
# Agrega los slots nocturnos 22:00-23:00, 23:00-00:00 y 00:00-01:00
# a TODAS las canchas existentes, para todos los dias de la semana.
#
# Ejecutar:
#   cd backend
#   venv/Scripts/python.exe add_horas_nocturnas.py
import asyncio
import uuid
from datetime import time

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select

from app.core.config import settings
from app.models.cancha import Cancha
from app.models.horario import HorarioDisponible


SLOTS_NUEVOS = [
    (time(22, 0), time(23, 0)),   # 22:00 – 23:00
    (time(23, 0), time(0, 0)),    # 23:00 – 00:00  (medianoche)
    (time(0, 0),  time(1, 0)),    # 00:00 – 01:00
]


async def main():
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with AsyncSessionLocal() as session:
        # Obtener todas las canchas activas
        result = await session.execute(select(Cancha).where(Cancha.activa == True))
        canchas = result.scalars().all()

        print(f"Canchas encontradas: {len(canchas)}")

        total_insertados = 0
        total_omitidos   = 0

        for cancha in canchas:
            for dia in range(7):           # 0=Lun ... 6=Dom
                for inicio, fin in SLOTS_NUEVOS:
                    # Verificar si ya existe el slot para evitar duplicados
                    existe = await session.execute(
                        select(HorarioDisponible).where(
                            HorarioDisponible.cancha_id == cancha.id,
                            HorarioDisponible.dia_semana == dia,
                            HorarioDisponible.hora_inicio == inicio,
                        )
                    )
                    if existe.scalar_one_or_none():
                        total_omitidos += 1
                        continue

                    horario = HorarioDisponible(
                        id=uuid.uuid4(),
                        cancha_id=cancha.id,
                        dia_semana=dia,
                        hora_inicio=inicio,
                        hora_fin=fin,
                        precio_override=None,
                        activo=True,
                    )
                    session.add(horario)
                    total_insertados += 1

        await session.commit()
        print(f"  OK Insertados: {total_insertados} horarios")
        print(f"  -- Omitidos (ya existian): {total_omitidos}")
        print("Horas nocturnas 22:00, 23:00 y 00:00 agregadas exitosamente.")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
