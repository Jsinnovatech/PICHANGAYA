from pydantic import BaseModel
# BaseModel es la clase base de Pydantic
# Define la estructura de los datos que entran y salen de la API
# Pydantic valida automáticamente que los datos sean del tipo correcto

from typing import Optional
# Optional[X] significa que el campo puede ser X o None (no obligatorio)

import uuid
# Para el tipo UUID de los IDs


class LocalResponse(BaseModel):
    # Define cómo se ve un local en la respuesta JSON
    # Cada campo aquí se convierte en una clave del JSON

    id: uuid.UUID
    # UUID del local — se serializa como string en JSON

    nombre: str
    # Nombre del complejo deportivo

    direccion: str
    # Dirección completa

    lat: float
    # Latitud GPS — número decimal

    lng: float
    # Longitud GPS — número decimal

    telefono: Optional[str] = None
    # Teléfono — opcional, puede no tener

    foto_url: Optional[str] = None
    # URL de la foto del local — opcional

    distancia_km: Optional[float] = None
    # Distancia desde el usuario hasta el local en km
    # Se calcula en el backend con Haversine
    # None si no se enviaron coordenadas GPS en la petición

    num_canchas: Optional[int] = None
    # Cantidad de canchas activas del local

    precio_desde: Optional[float] = None
    # Precio mínimo entre todas las canchas del local
    # Se muestra en el mapa: "Desde S/. 65 / hora"

    class Config:
        from_attributes = True
        # from_attributes=True permite crear este schema desde un objeto ORM
        # Sin esto: LocalResponse(**local.__dict__) fallaría


class CanchaResponse(BaseModel):
    # Define cómo se ve una cancha en la respuesta JSON

    id: uuid.UUID
    local_id: uuid.UUID

    nombre: str
    # Ej: "Cancha A", "Cancha B"

    capacidad: int
    # Número de jugadores — ej: 10, 12, 14

    precio_hora: float
    # Precio base en soles por hora

    precio_dia: Optional[float] = None
    # Precio por hora en franja diurna (07:00–18:00)

    precio_noche: Optional[float] = None
    # Precio por hora en franja nocturna (18:00–00:00)

    superficie: Optional[str] = None
    # "Gras Sintético" | "Piso Madera" | "Cemento"

    foto_url: Optional[str] = None

    activa: bool
    # True = disponible para reservar

    class Config:
        from_attributes = True


class SlotDisponibilidad(BaseModel):
    # Representa un slot de hora para una cancha en una fecha específica
    # Flutter usa esto para mostrar el grid de horarios

    hora_inicio: str
    # Formato "HH:MM" — ej: "07:00", "14:00"

    hora_fin: str
    # Formato "HH:MM" — ej: "08:00", "15:00"

    disponible: bool
    # True = libre para reservar
    # False = ya tiene una reserva activa

    precio: float
    # Precio del slot — puede ser diferente si hay precio_override
    # Ej: tarifa nocturna más cara