import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Request, UploadFile, status, Query
from sqlalchemy.orm import Session
from .models import Taller  # asegúrate que está importado arriba
from app.database import get_db
from app.dependencies import require_roles
from app.modules.usuarios.models import Usuario
from . import service
from .schema import TallerCreate, TallerOut, TallerUpdate, LogoTallerOut

router = APIRouter(prefix="/talleres", tags=["Talleres"])

# ── RUTAS PÚBLICAS ────────────────────────────────────────────────────────────

@router.get("/cercanos", response_model=List[TallerOut])
def listar_cercanos(
    lat: float = Query(..., description="Latitud del cliente"),
    lon: float = Query(..., description="Longitud del cliente"),
    radio: float = Query(10.0, description="Radio en KM"),
    db: Session = Depends(get_db)
):
    """Busca talleres activos cerca de la ubicación enviada"""
    return service.listar_talleres_cercanos(db, lat, lon, radio)

@router.get("/activos", response_model=List[TallerOut])
def listar_activos(db: Session = Depends(get_db)):
    return service.listar_talleres(db, solo_activos=True)

# ── TALLER / TÉCNICO ──────────────────────────────────────────────────────────

@router.post("/registro", response_model=TallerOut, status_code=201)
def registrar(data: TallerCreate, db: Session = Depends(get_db)):
    # Nota: Aquí quitamos require_roles si es un registro abierto al público
    return service.registrar_taller(db, data)

@router.put("/mi-taller/{taller_id}", response_model=TallerOut)
def actualizar_mi_taller(
    taller_id: uuid.UUID,
    data: TallerUpdate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_roles("tecnico", "admin"))
):
    return service.actualizar_taller(db, taller_id, data)

# ── ADMIN: GESTIÓN ────────────────────────────────────────────────────────────

@router.patch("/{taller_id}/estado", response_model=TallerOut)
def cambiar_estado(
    taller_id: uuid.UUID,
    activo: bool,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_roles("admin"))
):
    """Permite activar (True) o desactivar (False) un taller"""
    return service.cambiar_estado_taller(db, taller_id, activo)

@router.post("/{taller_id}/verificar", response_model=TallerOut)
def verificar(
    taller_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_roles("admin"))
):
    return service.verificar_taller(db, taller_id)

@router.get("/", response_model=List[TallerOut])
def listar_todos(db: Session = Depends(get_db), _=Depends(require_roles("admin"))):
    return service.listar_talleres(db, solo_activos=False)

@router.get("/mi-taller/{taller_id}", response_model=TallerOut)
def obtener_mi_taller(
    taller_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_roles("tecnico", "admin"))
):
    taller = db.query(Taller).filter(Taller.id == taller_id).first()  # ← T mayúscula
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
    return taller