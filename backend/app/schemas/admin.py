"""
Schemas Pydantic para el router admin.
Extraídos de app/routers/admin.py para mantener responsabilidad única.
"""
import re
import uuid
from datetime import date
from typing import List, Optional

from pydantic import BaseModel, field_validator, model_validator

from app.models.pago import MetodoPagoEnum
from app.models.reserva import EstadoReservaEnum, TipoDocEnum


# ─────────────────────────────────────────────────────────────
# Utilidad compartida: RUC peruano con dígito verificador
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
# Reservas — respuestas y requests del panel admin
# ─────────────────────────────────────────────────────────────

class ReservaAdminResponse(BaseModel):
    id: uuid.UUID
    codigo: str
    cliente_nombre: str
    cliente_celular: str
    cancha_nombre: Optional[str] = None
    local_nombre: Optional[str] = None
    fecha: date
    hora_inicio: str
    hora_fin: str
    precio_total: float
    estado: str
    tipo_doc: Optional[str] = None
    metodo_pago: Optional[str] = None
    voucher_url: Optional[str] = None
    pago_estado: Optional[str] = None
    pago_id: Optional[uuid.UUID] = None
    es_manual: bool = False
    dni_cliente: Optional[str] = None

    class Config:
        from_attributes = True


class VerificarPagoRequest(BaseModel):
    accion: str
    motivo: Optional[str] = None

    @field_validator("accion")
    @classmethod
    def accion_valida(cls, v: str) -> str:
        if v not in {"aprobar", "rechazar"}:
            raise ValueError("Acción inválida. Use 'aprobar' o 'rechazar'")
        return v


class CambiarEstadoReservaRequest(BaseModel):
    estado: EstadoReservaEnum
    # Enum tipado: pending | confirmed | active | done | canceled
    notas: Optional[str] = None


class ReservaManualRequest(BaseModel):
    cancha_id: uuid.UUID
    fecha: date
    hora_inicio: str   # "HH:MM"
    hora_fin: str      # "HH:MM"
    nombre_cliente: str
    dni_cliente: str
    metodo_pago: MetodoPagoEnum   # Enum: yape | plin | transferencia | efectivo | tarjeta
    tipo_doc: TipoDocEnum         # Enum: boleta | factura
    ruc_factura: Optional[str] = None
    razon_social: Optional[str] = None

    @field_validator("hora_inicio", "hora_fin")
    @classmethod
    def validar_formato_hora(cls, v: str) -> str:
        if not re.match(r"^\d{2}:\d{2}$", v):
            raise ValueError("Formato de hora debe ser HH:MM")
        h, m = map(int, v.split(":"))
        if not (0 <= h <= 23 and 0 <= m <= 59):
            raise ValueError("Hora inválida")
        return v

    @field_validator("fecha")
    @classmethod
    def fecha_no_pasada(cls, v) -> date:
        from datetime import date as date_type
        if v < date_type.today():
            raise ValueError("No se pueden crear reservas en fechas pasadas")
        return v

    @field_validator("ruc_factura")
    @classmethod
    def validar_ruc(cls, v):
        if v is not None and not _validar_ruc_peruano(v):
            raise ValueError("RUC inválido — verifica el dígito verificador")
        return v

    @model_validator(mode="after")
    def validar_campos_factura(self):
        if self.tipo_doc == TipoDocEnum.factura:
            if not self.ruc_factura:
                raise ValueError("RUC requerido para facturas")
            if not self.razon_social or not self.razon_social.strip():
                raise ValueError("Razón social requerida para facturas")
        return self

    @field_validator("nombre_cliente")
    @classmethod
    def nombre_no_vacio(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Nombre del cliente no puede estar vacío")
        return v.strip()

    @field_validator("dni_cliente")
    @classmethod
    def dni_valido(cls, v: str) -> str:
        v = v.strip()
        if not v.isdigit() or len(v) != 8:
            raise ValueError("DNI debe tener exactamente 8 dígitos")
        return v


# ─────────────────────────────────────────────────────────────
# Pagos — respuestas admin
# ─────────────────────────────────────────────────────────────

class PagoAdminResponse(BaseModel):
    id: uuid.UUID
    reserva_id: uuid.UUID
    reserva_codigo: Optional[str] = None
    cliente_nombre: Optional[str] = None
    cliente_celular: Optional[str] = None
    monto: float
    metodo: str
    estado: str
    voucher_url: Optional[str] = None
    fecha: Optional[str] = None

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────
# Clientes — respuesta admin
# ─────────────────────────────────────────────────────────────

class ClienteAdminResponse(BaseModel):
    id: uuid.UUID
    nombre: str
    celular: str
    dni: Optional[str] = None
    activo: bool
    total_reservas: int = 0
    total_gastado: float = 0.0

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────
# Slots y disponibilidad
# ─────────────────────────────────────────────────────────────

class SlotAdminResponse(BaseModel):
    hora_inicio: str
    hora_fin: str
    disponible: bool
    precio: float


class CanchaDisponibilidadResponse(BaseModel):
    cancha_id: uuid.UUID
    cancha_nombre: str
    tipo_piso: Optional[str] = None
    precio_hora: float
    precio_dia: Optional[float] = None
    precio_noche: Optional[float] = None
    slots: List[SlotAdminResponse]


# ─────────────────────────────────────────────────────────────
# Canchas — CRUD admin
# ─────────────────────────────────────────────────────────────

class CanchaAdminResponse(BaseModel):
    id: uuid.UUID
    local_id: uuid.UUID
    local_nombre: Optional[str] = None
    nombre: str
    descripcion: Optional[str] = None
    capacidad: int
    precio_hora: float
    superficie: Optional[str] = None
    activa: bool

    class Config:
        from_attributes = True


class CanchaCreateRequest(BaseModel):
    local_id: uuid.UUID
    nombre: str
    descripcion: Optional[str] = None
    capacidad: int = 10
    precio_hora: float
    superficie: Optional[str] = None

    @field_validator("nombre")
    @classmethod
    def nombre_no_vacio(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("El nombre de la cancha no puede estar vacío")
        return v.strip()

    @field_validator("capacidad")
    @classmethod
    def capacidad_positiva(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("La capacidad debe ser mayor a 0")
        return v

    @field_validator("precio_hora")
    @classmethod
    def precio_positivo(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("El precio por hora debe ser mayor a 0")
        return v


class CanchaUpdateRequest(BaseModel):
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    capacidad: Optional[int] = None
    precio_hora: Optional[float] = None
    superficie: Optional[str] = None

    @field_validator("capacidad")
    @classmethod
    def capacidad_positiva(cls, v):
        if v is not None and v <= 0:
            raise ValueError("La capacidad debe ser mayor a 0")
        return v

    @field_validator("precio_hora")
    @classmethod
    def precio_positivo(cls, v):
        if v is not None and v <= 0:
            raise ValueError("El precio por hora debe ser mayor a 0")
        return v


# ─────────────────────────────────────────────────────────────
# Timers — respuesta admin
# ─────────────────────────────────────────────────────────────

class TimerReservaResponse(BaseModel):
    id: uuid.UUID
    codigo: str
    cliente_nombre: str
    cliente_celular: str
    cancha_nombre: Optional[str] = None
    fecha: date
    hora_inicio: str
    hora_fin: str
    estado: str
    precio_total: float

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────
# Facturación — respuesta admin
# ─────────────────────────────────────────────────────────────

class FacturacionItemResponse(BaseModel):
    reserva_id: uuid.UUID
    codigo: str
    cliente_nombre: str
    cliente_celular: str
    cancha_nombre: Optional[str] = None
    fecha: date
    monto: float
    metodo_pago: str
    tipo_doc: Optional[str] = None
    ruc_factura: Optional[str] = None
    razon_social: Optional[str] = None
    comprobante_estado: Optional[str] = None
    comprobante_serie: Optional[str] = None
    comprobante_numero: Optional[int] = None
    pdf_url: Optional[str] = None
    fecha_pago: Optional[str] = None
    es_manual: bool = False
    dni_cliente: Optional[str] = None

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────
# Locales — CRUD admin
# ─────────────────────────────────────────────────────────────

class LocalAdminResponse(BaseModel):
    id: uuid.UUID
    nombre: str
    direccion: str
    lat: float
    lng: float
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    foto_url: Optional[str] = None
    activo: bool

    class Config:
        from_attributes = True


class LocalCreateRequest(BaseModel):
    nombre: str
    direccion: str
    lat: float
    lng: float
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    foto_url: Optional[str] = None

    @field_validator("nombre", "direccion")
    @classmethod
    def campos_no_vacios(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("El campo no puede estar vacío")
        return v.strip()

    @field_validator("lat")
    @classmethod
    def lat_valida(cls, v: float) -> float:
        if not (-90.0 <= v <= 90.0):
            raise ValueError("Latitud debe estar entre -90 y 90")
        return v

    @field_validator("lng")
    @classmethod
    def lng_valida(cls, v: float) -> float:
        if not (-180.0 <= v <= 180.0):
            raise ValueError("Longitud debe estar entre -180 y 180")
        return v


class LocalUpdateRequest(BaseModel):
    nombre: Optional[str] = None
    direccion: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    foto_url: Optional[str] = None
    activo: Optional[bool] = None

    @field_validator("lat")
    @classmethod
    def lat_valida(cls, v):
        if v is not None and not (-90.0 <= v <= 90.0):
            raise ValueError("Latitud debe estar entre -90 y 90")
        return v

    @field_validator("lng")
    @classmethod
    def lng_valida(cls, v):
        if v is not None and not (-180.0 <= v <= 180.0):
            raise ValueError("Longitud debe estar entre -180 y 180")
        return v


# ─────────────────────────────────────────────────────────────
# Bloqueos de horario
# ─────────────────────────────────────────────────────────────

class BloqueoCreateRequest(BaseModel):
    cancha_id: uuid.UUID
    fecha: date
    hora_inicio: str   # "HH:MM"
    hora_fin: str      # "HH:MM"
    motivo: Optional[str] = None

    @field_validator("hora_inicio", "hora_fin")
    @classmethod
    def validar_formato_hora(cls, v: str) -> str:
        if not re.match(r"^\d{2}:\d{2}$", v):
            raise ValueError("Formato de hora debe ser HH:MM")
        h, m = map(int, v.split(":"))
        if not (0 <= h <= 23 and 0 <= m <= 59):
            raise ValueError("Hora inválida")
        return v

    @field_validator("fecha")
    @classmethod
    def fecha_no_pasada(cls, v) -> date:
        from datetime import date as date_type
        if v < date_type.today():
            raise ValueError("No se pueden crear bloqueos en fechas pasadas")
        return v


class BloqueoResponse(BaseModel):
    id: uuid.UUID
    cancha_id: uuid.UUID
    cancha_nombre: Optional[str] = None
    fecha: date
    hora_inicio: str
    hora_fin: str
    motivo: Optional[str] = None

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────
# Medios de Pago — configuración por admin
# ─────────────────────────────────────────────────────────────

class MediosPagoResponse(BaseModel):
    yape_numero: Optional[str] = None
    qr_imagen_base64: Optional[str] = None
    cuenta_bcp: Optional[str] = None
    cuenta_bbva: Optional[str] = None


class MediosPagoRequest(BaseModel):
    yape_numero: Optional[str] = None
    qr_imagen_base64: Optional[str] = None
    cuenta_bcp: Optional[str] = None
    cuenta_bbva: Optional[str] = None
