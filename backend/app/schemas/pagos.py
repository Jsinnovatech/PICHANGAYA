from pydantic import BaseModel
from typing import Optional
import uuid


class VoucherUploadResponse(BaseModel):
    # Respuesta cuando el cliente sube su voucher exitosamente

    pago_id: uuid.UUID
    # ID del pago actualizado

    voucher_url: str
    # URL pública de la imagen en imgbb
    # Flutter la usa para mostrar el voucher al cliente

    estado: str
    # Estado del pago — sigue "pendiente" hasta que admin verifique


class PagoClienteResponse(BaseModel):
    # Para el tab "Pagos" de Mis Reservas en el prototipo HTML

    id: uuid.UUID
    reserva_id: uuid.UUID

    reserva_codigo: Optional[str] = None
    # Código amigable — ej: "RES-000001"

    monto: float
    # Monto en soles

    metodo: str
    # "yape" | "plin" | "transferencia" | "efectivo"

    estado: str
    # "pendiente" | "verificado" | "rechazado"

    voucher_url: Optional[str] = None
    # URL de la imagen — None si no subió voucher todavía

    fecha: Optional[str] = None
    # Fecha del pago

    class Config:
        from_attributes = True