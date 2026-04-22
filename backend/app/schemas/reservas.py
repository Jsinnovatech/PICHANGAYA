from pydantic import BaseModel
# BaseModel → clase base de Pydantic para validar datos

from typing import Optional
# Optional → campo que puede ser None

import uuid
# Para el tipo UUID de los IDs

from datetime import date
# date → tipo fecha YYYY-MM-DD


class ReservaCreateRequest(BaseModel):
    # Datos que Flutter envía al crear una reserva
    # Equivale al confirmarPagoConVoucher() del prototipo HTML

    cancha_id: uuid.UUID
    # ID de la cancha seleccionada

    fecha: date
    # Fecha de la reserva — ej: "2026-03-24"
    # Pydantic convierte automáticamente el string al tipo date

    hora_inicio: str
    # Hora del slot seleccionado — ej: "09:00"

    hora_fin: str
    # Hora de fin del slot — ej: "10:00"

    metodo_pago: str
    # "yape" | "plin" | "transferencia" | "efectivo"

    tipo_doc: Optional[str] = "boleta"
    # "boleta" | "factura" — por defecto boleta

    ruc_factura: Optional[str] = None
    # RUC de la empresa — obligatorio si tipo_doc = "factura" (11 dígitos)

    razon_social: Optional[str] = None
    # Razón social de la empresa — obligatorio si tipo_doc = "factura"


class ReservaResponse(BaseModel):
    # Datos que devuelve la API al crear una reserva exitosa
    # Flutter los usa para mostrar la confirmación al cliente

    id: uuid.UUID
    # ID interno de la reserva

    codigo: str
    # Código amigable — ej: "RES-000001"
    # El cliente lo usa para identificar su reserva

    cancha_nombre: Optional[str] = None
    # Nombre de la cancha — ej: "Cancha A"

    local_nombre: Optional[str] = None
    # Nombre del local — ej: "Complejo Deportivo El Golazo"

    fecha: date
    # Fecha de la reserva

    hora_inicio: str
    # Hora de inicio

    hora_fin: str
    # Hora de fin

    precio_total: float
    # Monto total a pagar en soles

    estado: str
    # Estado actual: "pending" al crear

    metodo_pago: Optional[str] = None
    # Método de pago seleccionado

    pago_id: Optional[uuid.UUID] = None
    # ID del pago creado — Flutter lo usa para subir el voucher después

    class Config:
        from_attributes = True


class MiReservaResponse(BaseModel):
    # Para el historial del cliente — tab "Mis Reservas" del prototipo HTML
    # Muestra todas las reservas del cliente logueado

    id: uuid.UUID
    codigo: str
    cancha_nombre: Optional[str] = None
    local_nombre: Optional[str] = None
    fecha: date
    hora_inicio: str
    hora_fin: str
    precio_total: float
    estado: str
    # "pending" | "confirmed" | "active" | "done" | "canceled"
    tipo_doc: Optional[str] = None
    metodo_pago: Optional[str] = None
    serie_fact: Optional[str] = None
    # Serie del comprobante emitido — ej: "B001-00001"

    class Config:
        from_attributes = True