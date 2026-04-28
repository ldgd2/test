import uuid
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from uuid import UUID


# ── Registro ──────────────────────────────────────────────────────────────────
class UsuarioCreate(BaseModel):
    nombres: str
    apellidos: str
    email: EmailStr
    telefono: Optional[str] = None
    password: str
    tipo: Optional[str] = "cliente"


# ── Actualizar perfil ─────────────────────────────────────────────────────────
class UsuarioUpdate(BaseModel):
    nombres: Optional[str] = None
    apellidos: Optional[str] = None
    email: Optional[EmailStr] = None
    telefono: Optional[str] = None
    activo: Optional[bool] = None
    foto_perfil_url: Optional[str] = None

    @field_validator("nombres", "apellidos")
    @classmethod
    def no_vacio(cls, v):
        if v is not None and not v.strip():
            raise ValueError("El campo no puede estar vacío")
        return v


# ── Respuesta ─────────────────────────────────────────────────────────────────
class UsuarioOut(BaseModel):
    id: UUID
    nombres: str
    apellidos: str
    email: str
    telefono: Optional[str] = None
    tipo: str
    activo: bool
    foto_perfil_url: Optional[str] = None
    taller_id:       Optional[UUID] = None 

    model_config = {"from_attributes": True}


# ── Login ─────────────────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    email: EmailStr
    password: str


# ── Tokens ────────────────────────────────────────────────────────────────────
class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    usuario: UsuarioOut


class RefreshRequest(BaseModel):
    refresh_token: str


# ── Cambiar contraseña ────────────────────────────────────────────────────────
class CambiarPassword(BaseModel):
    password_actual: str
    password_nueva: str

    @field_validator("password_nueva")
    @classmethod
    def min_length(cls, v):
        if len(v) < 8:
            raise ValueError("La contraseña debe tener al menos 8 caracteres")
        return v


# ── Respuesta al subir foto ───────────────────────────────────────────────────
class FotoPerfilOut(BaseModel):
    foto_perfil_url: str
    mensaje: str = "Foto de perfil actualizada correctamente"