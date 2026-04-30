import re
import uuid
from datetime import date as date_type
from typing import Optional

from pydantic import BaseModel, field_validator, model_validator

from app.models.pago import MetodoPagoEnum
from app.models.reserva import TipoDocEnum


# ─────────────────────────────────────────────────────────────
# Utilidad: validación de RUC peruano con dígito verificador
# ─────────────────────────────────────────────────────────────

def _validar_ruc_peruano(ruc: str) -> bool:
    """Valida RUC peruano de 11 dígitos usando el algoritmo del dígito verificador."""
    if not ruc or not ruc.isdigit() or len(ruc) != 11:
        return False
    factores = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]
    suma = sum(int(ruc[i]) * factores[i] for i in range(10))
    residuo = suma % 11
    digito = 11 - residuo
    if digito >= 10:
        digito -= 10
    return digito == int(ruc[10])


# ─────────────────────────────────────────────────────────────
# Schema de creación de reserva
# ─────────────────────────────────────────────────────────────

class ReservaCreateRequest(BaseModel):
    # Datos que Flutter envía al crear una reserva
    # Equivale al confirmarPagoConVoucher() del prototipo HTML

    cancha_id: uuid.UUID
    # ID de la cancha seleccionada

    fecha: date_type
    # Fecha de la reserva — ej: "2026-03-24"
    # Pydantic convierte automáticamente el string al tipo date

    hora_inicio: str
    # Hora del slot seleccionado — ej: "09:00"

    hora_fin: str
    # Hora de fin del slot — ej: "10:00"

    metodo_pago: MetodoPagoEnum
    # Enum: yape | plin | transferencia | efectivo | tarjeta

    tipo_doc: Optional[TipoDocEnum] = TipoDocEnum.boleta
    # Enum: boleta | factura — por defecto boleta

    ruc_factura: Optional[str] = None
    # RUC de la empresa — obligatorio si tipo_doc = factura (11 dígitos + dígito verificador)

    razon_social: Optional[str] = None
    # Razón social de la empresa — obligatorio si tipo_doc = factura

    # ── Validadores de hora ────────────────────────────────────

    @field_validator("hora_inicio", "hora_fin")
    @classmethod
    def validar_formato_hora(cls, v: str) -> str:
        if not re.match(r"^\d{2}:\d{2}$", v):
            raise ValueError("Formato de hora debe ser HH:MM")
        h, m = map(int, v.split(":"))
        # 24:00 es válido como alias de medianoche (fin del slot nocturno 23:00-24:00)
        if h == 24 and m == 0:
            return "00:00"
        if not (0 <= h <= 23 and 0 <= m <= 59):
            raise ValueError("Hora inválida")
        return v

    # ── Validador de fecha ────────────────────────────────────

    @field_validator("fecha")
    @classmethod
    def fecha_no_pasada(cls, v) -> date_type:
        from datetime import datetime, timezone, timedelta
        # Usar zona horaria Perú (UTC-5) para evitar rechazar "hoy" cuando
        # el servidor Railway corre en UTC y ya pasó la medianoche UTC.
        peru_hoy = datetime.now(timezone(timedelta(hours=-5))).date()
        if v < peru_hoy:
            raise ValueError("No se pueden reservar fechas pasadas")
        return v

    # ── Validador de RUC con dígito verificador ───────────────

    @field_validator("ruc_factura")
    @classmethod
    def validar_ruc(cls, v):
        if v is not None and not _validar_ruc_peruano(v):
            raise ValueError("RUC inválido — verifica el dígito verificador")
        return v

    # ── Validación condicional factura ────────────────────────

    @model_validator(mode="after")
    def validar_campos_factura(self):
        if self.tipo_doc == TipoDocEnum.factura:
            if not self.ruc_factura:
                raise ValueError("RUC requerido para facturas")
            if not self.razon_social or not self.razon_social.strip():
                raise ValueError("Razón social requerida para facturas")
        return self


# ─────────────────────────────────────────────────────────────
# Schema de respuesta al crear reserva
# ─────────────────────────────────────────────────────────────

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

    fecha: date_type
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


# ─────────────────────────────────────────────────────────────
# Schema del historial del cliente
# ─────────────────────────────────────────────────────────────

class MiReservaResponse(BaseModel):
    # Para el historial del cliente — tab "Mis Reservas" del prototipo HTML
    # Muestra todas las reservas del cliente logueado

    id: uuid.UUID
    codigo: str
    cancha_nombre: Optional[str] = None
    local_nombre: Optional[str] = None
    fecha: date_type
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
