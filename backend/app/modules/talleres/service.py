import uuid
import math
from decimal import Decimal
from pathlib import Path
from typing import Optional, List

from fastapi import HTTPException, UploadFile, status
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from .models import Taller
from .schema import TallerCreate, TallerUpdate

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

UPLOAD_DIR = Path("static/logos_talleres")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

EXTENSIONES_PERMITIDAS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_SIZE_BYTES = 5 * 1024 * 1024

def _get_or_404(db: Session, taller_id: uuid.UUID) -> Taller:
    t = db.query(Taller).filter(Taller.id == taller_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
    return t

# --- LÓGICA DE GEOLOCALIZACIÓN ---
def calcular_distancia(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0  # Radio de la Tierra en km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def listar_talleres_cercanos(db: Session, lat_c: float, lon_c: float, radio_km: float) -> List[Taller]:
    talleres = db.query(Taller).filter(Taller.activo == True).all()
    cercanos = []
    for t in talleres:
        if t.latitud is not None and t.longitud is not None:
            distancia = calcular_distancia(lat_c, lon_c, float(t.latitud), float(t.longitud))
            if distancia <= radio_km:
                cercanos.append(t)
    return cercanos

# --- CRUD MEJORADO ---
def registrar_taller(db: Session, data: TallerCreate) -> Taller:
    if db.query(Taller).filter(Taller.email == data.email).first():
        raise HTTPException(status_code=409, detail="El email ya está registrado")

    taller = Taller(
        id=uuid.uuid4(),
        nombre=data.nombre,
        email=data.email,
        password_hash=pwd_context.hash(data.password),
        telefono=data.telefono,
        direccion=data.direccion,
        radio_servicio_km=data.radio_servicio_km,
        descripcion=data.descripcion,
        latitud=data.latitud,   # Guardamos latitud
        longitud=data.longitud  # Guardamos longitud
    )
    db.add(taller)
    db.commit()
    db.refresh(taller)
    return taller

def actualizar_taller(db: Session, taller_id: uuid.UUID, data: TallerUpdate) -> Taller:
    t = _get_or_404(db, taller_id)
    for campo, valor in data.model_dump(exclude_unset=True).items():
        if campo == "password" and valor:
            t.password_hash = pwd_context.hash(valor)
        else:
            setattr(t, campo, valor)
    db.commit()
    db.refresh(t)
    return t

# --- CAMBIO DE ESTADO (ACTIVAR/DESACTIVAR) ---
def cambiar_estado_taller(db: Session, taller_id: uuid.UUID, activo: bool) -> Taller:
    t = _get_or_404(db, taller_id)
    t.activo = activo
    db.commit()
    db.refresh(t)
    return t

# ... (resto de funciones listar, verificar, subir_logo se mantienen igual)