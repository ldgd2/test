from pydantic import BaseModel, ConfigDict
from uuid import UUID
from typing import Optional
from datetime import datetime


class IncidenteBase(BaseModel):
    vehiculo_id:        UUID
    direccion_texto:    str
    ubicacion:          Optional[str] = None
    descripcion_manual: str
    categoria:          str = "incierto"
    prioridad:          str = "media"


class IncidenteCreate(BaseModel):
    vehiculo_id:        UUID
    categoria:          str
    descripcion_manual: str
    direccion_texto:    str
    ubicacion:          str = "0,0"
    prioridad:          str = "media"


class IncidenteResponse(BaseModel):
    id:                 UUID
    usuario_id:         UUID
    vehiculo_id:        UUID
    direccion_texto:    str
    ubicacion:          Optional[str]   = None
    descripcion_manual: str
    categoria:          str
    prioridad:          str
    estado:             str
    resumen_ia:         Optional[str]   = None
    confianza_ia:       Optional[float] = None
    requiere_revision:  bool
    foto_evidencia:     Optional[str]   = None
    created_at:         datetime
    model_config = ConfigDict(from_attributes=True)


class EvidenciaResponse(BaseModel):
    id:           UUID
    incidente_id: UUID
    ruta_foto:    str
    descripcion:  Optional[str] = None
    created_at:   datetime
    model_config = ConfigDict(from_attributes=True)


class VehiculoDetalle(BaseModel):
    placa:  str
    marca:  str
    modelo: str
    anio:   int
    color:  Optional[str] = None
    model_config = ConfigDict(from_attributes=True)


class ClienteDetalle(BaseModel):
    nombres:   str
    apellidos: str
    telefono:  Optional[str] = None
    email:     str
    model_config = ConfigDict(from_attributes=True)


class IncidenteDetalleResponse(BaseModel):
    id:                 UUID
    descripcion_manual: str
    categoria:          str
    prioridad:          str
    estado:             str
    direccion_texto:    Optional[str]   = None
    ubicacion:          Optional[str]   = None
    foto_evidencia:     Optional[str]   = None
    distancia_km:       Optional[float] = None
    # ── IA ──
    resumen_ia:         Optional[str]   = None
    confianza_ia:       Optional[float] = None
    requiere_revision:  Optional[bool]  = None
    created_at:         datetime
    vehiculo:           Optional[VehiculoDetalle] = None
    cliente:            Optional[ClienteDetalle]  = None
    model_config = ConfigDict(from_attributes=True)