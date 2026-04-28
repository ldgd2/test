from pydantic import BaseModel, field_validator
from typing import Optional
from uuid import UUID

COMBUSTIBLES = {"gasolina", "diesel", "electrico", "hibrido", "gas"}

class VehiculoCreate(BaseModel):
    placa:       str
    marca:       str
    modelo:      str
    anio:        int
    color:       Optional[str] = None
    combustible: Optional[str] = "gasolina"

    @field_validator("anio")
    @classmethod
    def validar_anio(cls, v):
        if not (1900 <= v <= 2100):
            raise ValueError("El año debe estar entre 1900 y 2100")
        return v

    @field_validator("combustible")
    @classmethod
    def validar_combustible(cls, v):
        if v not in COMBUSTIBLES:
            raise ValueError(f"Combustible inválido. Opciones: {list(COMBUSTIBLES)}")
        return v

    @field_validator("placa", "marca", "modelo")
    @classmethod
    def no_vacio(cls, v):
        if not v or not v.strip():
            raise ValueError("El campo no puede estar vacío")
        return v.strip()


class VehiculoUpdate(BaseModel):
    placa:       Optional[str] = None
    marca:       Optional[str] = None
    modelo:      Optional[str] = None
    anio:        Optional[int] = None
    color:       Optional[str] = None
    combustible: Optional[str] = None
    activo:      Optional[bool] = None

    @field_validator("anio")
    @classmethod
    def validar_anio(cls, v):
        if v is not None and not (1900 <= v <= 2100):
            raise ValueError("El año debe estar entre 1900 y 2100")
        return v

    @field_validator("combustible")
    @classmethod
    def validar_combustible(cls, v):
        if v is not None and v not in COMBUSTIBLES:
            raise ValueError(f"Combustible inválido. Opciones: {list(COMBUSTIBLES)}")
        return v


class VehiculoOut(BaseModel):
    id:          UUID
    usuario_id:  UUID
    placa:       str
    marca:       str
    modelo:      str
    anio:        int
    color:       Optional[str] = None
    combustible: str
    foto_url:    Optional[str] = None
    activo:      bool

    model_config = {"from_attributes": True}


class FotoVehiculoOut(BaseModel):
    foto_url: str
    mensaje:  str = "Foto del vehículo actualizada correctamente"