from fastapi import APIRouter, Depends, UploadFile, File, Request, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
import uuid

from app.database import get_db
from app.dependencies import get_current_user, require_roles
from app.modules.usuarios import service
from app.modules.usuarios.schema import (
    UsuarioCreate, UsuarioUpdate, UsuarioOut,
    LoginRequest, TokenResponse, RefreshRequest,
    CambiarPassword, FotoPerfilOut
)
from app.modules.bitacora import service as bitacora_service
from .models import Usuario

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])


# ── Helper de autorización ───────────────────────────────────────────────────
def _verificar_permiso(current_user: Usuario, usuario_id: uuid.UUID):
    """Solo el propio usuario o un admin pueden modificar el perfil."""
    if current_user.id != usuario_id and current_user.tipo != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para modificar este perfil",
        )


# ── Auth ─────────────────────────────────────────────────────────────────────
@router.post("/registro", response_model=UsuarioOut, status_code=201)
def registro(data: UsuarioCreate, db: Session = Depends(get_db)):
    return service.crear_usuario(db, data)


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, request: Request, db: Session = Depends(get_db)):
    result = service.login(db, data.email, data.password)
    bitacora_service.registrar_accion(
        db=db,
        usuario=result["usuario"],
        accion="login",
        ip=request.client.host
    )
    return result


@router.post("/logout")
def logout(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    bitacora_service.registrar_accion(
        db=db,
        usuario=current_user,
        accion="logout"
    )
    return {"detail": "Sesión cerrada correctamente"}


@router.post("/refresh", response_model=TokenResponse)
def refresh(data: RefreshRequest, db: Session = Depends(get_db)):
    return service.refresh_token(db, data.refresh_token)


# ── Perfil propio ─────────────────────────────────────────────────────────────
@router.get("/me", response_model=UsuarioOut)
def mi_perfil(current_user: Usuario = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UsuarioOut)
def actualizar_mi_perfil(
    data: UsuarioUpdate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    return service.actualizar_usuario(db, str(current_user.id), data)


@router.put("/me/password", response_model=UsuarioOut, status_code=status.HTTP_200_OK)
def cambiar_mi_password(
    datos: CambiarPassword,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    return service.cambiar_password(db, current_user.id, datos)


@router.post("/me/foto", response_model=FotoPerfilOut, status_code=status.HTTP_200_OK)
async def subir_mi_foto(
    request: Request,
    foto: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    base_url = str(request.base_url).rstrip("/")
    url = await service.subir_foto_perfil(db, current_user.id, foto, base_url)
    return FotoPerfilOut(foto_perfil_url=url)


# ── Admin: CRUD usuarios ──────────────────────────────────────────────────────
@router.get("/", response_model=List[UsuarioOut])
def listar(db: Session = Depends(get_db), _=Depends(require_roles("admin"))):
    return service.listar_usuarios(db)


@router.get("/{user_id}", response_model=UsuarioOut)
def obtener(user_id: UUID, db: Session = Depends(get_db), _=Depends(require_roles("admin"))):
    return service.obtener_usuario(db, str(user_id))


@router.put("/{user_id}", response_model=UsuarioOut)
def actualizar(user_id: UUID, data: UsuarioUpdate, db: Session = Depends(get_db), _=Depends(require_roles("admin"))):
    return service.actualizar_usuario(db, str(user_id), data)


@router.post("/{user_id}/activar", response_model=UsuarioOut)
def activar(user_id: UUID, db: Session = Depends(get_db), _=Depends(require_roles("admin"))):
    return service.activar_usuario(db, str(user_id))


@router.post("/{user_id}/desactivar", response_model=UsuarioOut)
def desactivar(user_id: UUID, db: Session = Depends(get_db), _=Depends(require_roles("admin"))):
    return service.desactivar_usuario(db, str(user_id))


# ── Admin: foto y password por id ─────────────────────────────────────────────
@router.put("/{usuario_id}/password", response_model=UsuarioOut, status_code=status.HTTP_200_OK)
def cambiar_password(
    usuario_id: UUID,
    datos: CambiarPassword,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    _verificar_permiso(current_user, usuario_id)
    return service.cambiar_password(db, usuario_id, datos)


@router.post("/{usuario_id}/foto", response_model=FotoPerfilOut, status_code=status.HTTP_200_OK)
async def subir_foto(
    usuario_id: UUID,
    request: Request,
    foto: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    _verificar_permiso(current_user, usuario_id)
    base_url = str(request.base_url).rstrip("/")
    url = await service.subir_foto_perfil(db, usuario_id, foto, base_url)
    return FotoPerfilOut(foto_perfil_url=url)

@router.patch("/{usuario_id}/taller")
def asignar_taller(
    usuario_id: uuid.UUID,
    data: dict,
    db: Session = Depends(get_db),
):
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    usuario.taller_id = data.get("taller_id")
    db.commit()
    db.refresh(usuario)
    return {"ok": True, "taller_id": str(usuario.taller_id)}

@router.post("/fcm-token")
def guardar_fcm_token(
    data: dict,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    current_user.fcm_token = data.get('fcm_token')
    db.commit()
    return {"ok": True}