from pydantic import BaseModel, ConfigDict
from uuid import UUID
from typing import Optional
from datetime import datetime


# ── CREAR PAGO (técnico envía desde Angular) ──────────────────────────────
class PagoCreate(BaseModel):
    asignacion_id: UUID
    monto_total:   float
    metodo:        str          # efectivo | qr | tarjeta | transferencia
    descripcion:   str          # descripción del servicio realizado
    qr_imagen_url: Optional[str] = None   # URL del QR si aplica


# ── SUBIR COMPROBANTE (cliente desde Flutter) ─────────────────────────────
class ComprobanteUpload(BaseModel):
    referencia_externa: Optional[str] = None


# ── RESPUESTA PAGO ────────────────────────────────────────────────────────
class PagoOut(BaseModel):
    id:                  UUID
    asignacion_id:       UUID
    usuario_id:          UUID
    monto_total:         float
    comision_plataforma: float
    monto_taller:        float
    metodo:              str
    estado:              str
    descripcion:         Optional[str]  = None
    qr_imagen_url:       Optional[str]  = None
    comprobante_url:     Optional[str]  = None
    referencia_externa:  Optional[str]  = None
    pagado_at:           Optional[datetime] = None
    created_at:          datetime

    model_config = ConfigDict(from_attributes=True)


# ── DETALLE PAGO CON INFO EXTRA (para el cliente Flutter) ────────────────
class PagoDetalleOut(BaseModel):
    id:                  UUID
    asignacion_id:       UUID
    monto_total:         float
    comision_plataforma: float
    monto_taller:        float
    metodo:              str
    estado:              str
    descripcion:         Optional[str]  = None
    qr_imagen_url:       Optional[str]  = None
    comprobante_url:     Optional[str]  = None
    referencia_externa:  Optional[str]  = None
    pagado_at:           Optional[datetime] = None
    created_at:          datetime

    # Info del taller
    taller_nombre:       Optional[str]  = None
    tecnico_nombre:      Optional[str]  = None

    # Info del incidente
    categoria:           Optional[str]  = None
    descripcion_incidente: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


# ── CONFIRMAR PAGO ────────────────────────────────────────────────────────
class ConfirmarPagoRequest(BaseModel):
    metodo:             str                  # efectivo | qr
    referencia_externa: Optional[str] = None # número de transacción si aplica