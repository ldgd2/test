from pydantic import BaseModel, EmailStr, field_validator, Field
from typing import Optional
from uuid import UUID
from decimal import Decimal

# --- CLASE BASE PARA EVITAR REPETICIÓN (DRY) ---
class TallerBase(BaseModel):
    nombre:            Optional[str] = Field(None, min_length=1, max_length=150)
    telefono:          Optional[str] = None
    direccion:         Optional[str] = None
    radio_servicio_km: Optional[Decimal] = Field(Decimal("10"), ge=0.1)
    descripcion:       Optional[str] = None
    latitud:           Optional[float] = Field(None, ge=-90, le=90)
    longitud:          Optional[float] = Field(None, ge=-180, le=180)

    @field_validator("nombre")
    @classmethod
    def nombre_no_vacio(cls, v):
        if v is not None and not v.strip():
            raise ValueError("El nombre no puede estar vacío")
        return v.strip() if v else v

# --- ESQUEMA DE CREACIÓN ---
class TallerCreate(TallerBase):
    nombre:   str  # Re-declaramos como obligatorio
    email:    EmailStr
    password: str = Field(..., min_length=8)

    @field_validator("password")
    @classmethod
    def password_min(cls, v):
        if len(v) < 8:
            raise ValueError("La contraseña debe tener al menos 8 caracteres")
        return v

# --- ESQUEMA DE ACTUALIZACIÓN ---
class TallerUpdate(TallerBase):
    password: Optional[str] = Field(None, min_length=8)
    activo:   Optional[bool] = None

# --- ESQUEMA DE SALIDA (LO QUE VE EL CLIENTE) ---
class TallerOut(TallerBase):
    id:                UUID
    email:             str
    logo_url:          Optional[str] = None
    activo:            bool
    verificado:        bool
    comision_pct:      Decimal
    
    # Aseguramos que el cliente reciba la ubicación para dibujar el mapa
    latitud:           Optional[float]
    longitud:          Optional[float]

    class Config:
        from_attributes = True

# --- OTROS ESQUEMAS ---
class TallerLoginRequest(BaseModel):
    email:    EmailStr
    password: str

class LogoTallerOut(BaseModel):
    logo_url: str
    mensaje:  str = "Logo actualizado correctamente"