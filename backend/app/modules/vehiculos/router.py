import uuid
from typing import List

from fastapi import APIRouter, Depends, File, Request, UploadFile, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user, require_roles
from app.modules.usuarios.models import Usuario
from . import service
from .schema import VehiculoCreate, VehiculoOut, VehiculoUpdate, FotoVehiculoOut

router = APIRouter(prefix="/vehiculos", tags=["Vehículos"])

# ── Rutas fijas primero (sin parámetros) ──────────────────────────────────────

@router.get("/mis-vehiculos", response_model=List[VehiculoOut])
def mis_vehiculos(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    return service.listar_mis_vehiculos(db, current_user.id)


@router.get("/todos", response_model=List[VehiculoOut])
def listar_todos(
    db: Session = Depends(get_db),
    _=Depends(require_roles("admin"))
):
    return service.listar_todos(db)


@router.post("/", response_model=VehiculoOut, status_code=201)
def registrar(
    data: VehiculoCreate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    return service.crear_vehiculo(db, current_user.id, data)


# ── Rutas con parámetro {vehiculo_id} al final ───────────────────────────────

@router.post("/{vehiculo_id}/foto", response_model=FotoVehiculoOut)
async def subir_foto(
    vehiculo_id: uuid.UUID,
    request: Request,
    foto: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    print(">>>>>> FOTO RECIBIDA:", foto.filename, foto.content_type)  # ← agrega esto
    
    es_admin = current_user.tipo == "admin"
    base_url = str(request.base_url).rstrip("/")
    url = await service.subir_foto(db, vehiculo_id, foto, base_url, current_user.id, es_admin)
    return FotoVehiculoOut(foto_url=url)

@router.get("/{vehiculo_id}", response_model=VehiculoOut)
def obtener(
    vehiculo_id: uuid.UUID,
    db: Session = Depends(get_db),
    _=Depends(require_roles("admin"))
):
    return service.obtener_vehiculo(db, vehiculo_id)


@router.put("/{vehiculo_id}", response_model=VehiculoOut)
def actualizar(
    vehiculo_id: uuid.UUID,
    data: VehiculoUpdate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    es_admin = current_user.tipo == "admin"
    return service.actualizar_vehiculo(db, vehiculo_id, data, current_user.id, es_admin)


@router.delete("/{vehiculo_id}", status_code=200)
def eliminar(
    vehiculo_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user)
):
    es_admin = current_user.tipo == "admin"
    return service.eliminar_vehiculo(db, vehiculo_id, current_user.id, es_admin)


