import uuid
import os
from pathlib import Path
from typing import Optional

from fastapi import UploadFile, HTTPException, status
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token
)
from .models import Usuario
from .schema import UsuarioCreate, UsuarioUpdate, CambiarPassword

# ── Configuración ─────────────────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ROLES_VALIDOS = {"cliente", "admin", "tecnico"}

UPLOAD_DIR = Path("static/fotos_perfil")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

EXTENSIONES_PERMITIDAS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_SIZE_BYTES = 5 * 1024 * 1024  # 5 MB


# ── Helper interno ────────────────────────────────────────────────────────────
def get_usuario_or_404(db: Session, usuario_id: uuid.UUID) -> Usuario:
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )
    return usuario


# ── Auth ──────────────────────────────────────────────────────────────────────
def crear_usuario(db: Session, data: UsuarioCreate) -> Usuario:
    if data.tipo not in ROLES_VALIDOS:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo inválido. Opciones: {list(ROLES_VALIDOS)}"
        )
    if db.query(Usuario).filter(Usuario.email == data.email).first():
        raise HTTPException(status_code=400, detail="El email ya está registrado")

    usuario = Usuario(
        id=uuid.uuid4(),
        nombres=data.nombres,
        apellidos=data.apellidos,
        email=data.email,
        telefono=data.telefono,
        password_hash=hash_password(data.password),
        tipo=data.tipo,
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)
    return usuario


def login(db: Session, email: str, password: str) -> dict:
    usuario = db.query(Usuario).filter(Usuario.email == email).first()
    if not usuario or not verify_password(password, usuario.password_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    if not usuario.activo:
        raise HTTPException(status_code=403, detail="Cuenta desactivada")

    payload = {"sub": str(usuario.id), "tipo": usuario.tipo , "taller_id": str(usuario.taller_id) if usuario.taller_id else None 
               }
    return {
        "access_token":  create_access_token(payload),
        "refresh_token": create_refresh_token(payload),
        "token_type":    "bearer",
        "usuario":       usuario,
    }


def refresh_token(db: Session, token: str) -> dict:
    payload = decode_token(token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Refresh token inválido")
    usuario = db.query(Usuario).filter(Usuario.id == payload["sub"]).first()
    if not usuario or not usuario.activo:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")

    new_payload = {"sub": str(usuario.id), "tipo": usuario.tipo ,"taller_id": str(usuario.taller_id) if usuario.taller_id else None}
    return {
        "access_token":  create_access_token(new_payload),
        "refresh_token": create_refresh_token(new_payload),
        "token_type":    "bearer",
        "usuario":       usuario,
    }


# ── CRUD usuarios ─────────────────────────────────────────────────────────────
def listar_usuarios(db: Session):
    return db.query(Usuario).all()


def obtener_usuario(db: Session, user_id: str) -> Usuario:
    u = db.query(Usuario).filter(Usuario.id == user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return u


def actualizar_usuario(db: Session, user_id: str, data: UsuarioUpdate) -> Usuario:
    u = obtener_usuario(db, user_id)
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(u, field, value)
    db.commit()
    db.refresh(u)
    return u


def activar_usuario(db: Session, user_id: str) -> Usuario:
    u = obtener_usuario(db, user_id)
    u.activo = True
    db.commit()
    db.refresh(u)
    return u


def desactivar_usuario(db: Session, user_id: str) -> Usuario:
    u = obtener_usuario(db, user_id)
    u.activo = False
    db.commit()
    db.refresh(u)
    return u


# ── Perfil ────────────────────────────────────────────────────────────────────
def actualizar_perfil(
    db: Session,
    usuario_id: uuid.UUID,
    datos: UsuarioUpdate,
) -> Usuario:
    usuario = get_usuario_or_404(db, usuario_id)

    if datos.email and datos.email != usuario.email:
        existe = (
            db.query(Usuario)
            .filter(Usuario.email == datos.email, Usuario.id != usuario_id)
            .first()
        )
        if existe:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El correo electrónico ya está registrado",
            )

    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(usuario, campo, valor)

    db.commit()
    db.refresh(usuario)
    return usuario


def cambiar_password(
    db: Session,
    usuario_id: uuid.UUID,
    datos: CambiarPassword,
) -> Usuario:
    usuario = get_usuario_or_404(db, usuario_id)

    if not pwd_context.verify(datos.password_actual, usuario.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La contraseña actual es incorrecta",
        )

    usuario.password_hash = pwd_context.hash(datos.password_nueva)
    db.commit()
    db.refresh(usuario)
    return usuario


async def subir_foto_perfil(
    db: Session,
    usuario_id: uuid.UUID,
    foto: UploadFile,
    base_url: str,
) -> str:
    usuario = get_usuario_or_404(db, usuario_id)

    ext = Path(foto.filename).suffix.lower()
    if ext not in EXTENSIONES_PERMITIDAS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Formato no permitido. Usa: {', '.join(EXTENSIONES_PERMITIDAS)}",
        )

    contenido = await foto.read()
    if len(contenido) > MAX_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="La imagen supera el límite de 5 MB",
        )

    if usuario.foto_perfil_url:
        ruta_anterior = _url_a_ruta(usuario.foto_perfil_url, base_url)
        if ruta_anterior and ruta_anterior.exists():
            ruta_anterior.unlink(missing_ok=True)

    nombre_archivo = f"{usuario_id}{ext}"
    ruta_destino = UPLOAD_DIR / nombre_archivo
    ruta_destino.write_bytes(contenido)

    url_publica = f"{base_url}/static/fotos_perfil/{nombre_archivo}"
    usuario.foto_perfil_url = url_publica
    db.commit()
    db.refresh(usuario)
    return url_publica


def _url_a_ruta(url: str, base_url: str) -> Optional[Path]:
    try:
        relativa = url.replace(base_url + "/", "")
        return Path(relativa)
    except Exception:
        return None