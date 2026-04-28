from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional


# ══════════════════════════════════════════════════
# ASIGNACIÓN
# ══════════════════════════════════════════════════

class AsignacionOut(BaseModel):
    asignacion_id:       UUID
    incidente_id:        UUID
    estado:              str
    distancia_km:        Optional[float] = None
    tiempo_estimado_min: Optional[int]   = None
    precio_cotizado:     Optional[float] = None
    nota_taller:         Optional[str]   = None
    created_at:          datetime

    # Del incidente
    descripcion_manual:  Optional[str] = None
    direccion_texto:     Optional[str] = None
    categoria:           Optional[str] = None
    prioridad:           Optional[str] = None

    # Del vehículo
    placa:               Optional[str] = None
    marca_vehiculo:      Optional[str] = None
    modelo_vehiculo:     Optional[str] = None
    color_vehiculo:      Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


# ══════════════════════════════════════════════════
# HISTORIAL — schemas
# ══════════════════════════════════════════════════

class HistorialAsignacionOut(BaseModel):
    id:               UUID
    asignacion_id:    UUID
    estado_anterior:  Optional[str] = None
    estado_nuevo:     str
    fuente:           Optional[str] = None
    nota:             Optional[str] = None
    created_at:       datetime

    model_config = ConfigDict(from_attributes=True)


# ══════════════════════════════════════════════════
# HISTORIAL DEL TÉCNICO — vista enriquecida
# ══════════════════════════════════════════════════

class VehiculoResumen(BaseModel):
    placa:  str
    marca:  str
    modelo: str
    color:  Optional[str] = None

class CasoHistorialOut(BaseModel):
    asignacion_id:      UUID
    incidente_id:       UUID
    estado:             str               # aceptada | en_camino | completada | cancelada
    categoria:          Optional[str] = None
    prioridad:          Optional[str] = None
    descripcion_manual: Optional[str] = None
    direccion_texto:    Optional[str] = None
    distancia_km:       Optional[float] = None
    precio_cotizado:    Optional[float] = None
    foto_evidencia:     Optional[str]   = None
    aceptado_at:        Optional[datetime] = None
    completado_at:      Optional[datetime] = None
    created_at:         datetime
    vehiculo:           Optional[VehiculoResumen] = None
    resumen_ia:        Optional[str]   = None  # ← agrega
    confianza_ia:      Optional[float] = None  # ← agrega
    requiere_revision: Optional[bool]  = None  # ← agrega

    model_config = ConfigDict(from_attributes=True)


# ══════════════════════════════════════════════════
# CAMBIO DE ESTADO
# ══════════════════════════════════════════════════

class CambiarEstadoRequest(BaseModel):
    nuevo_estado: str   # en_camino | completada | cancelada
    nota:         Optional[str] = None