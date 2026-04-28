import uuid
from pathlib import Path
from typing import Optional

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from .models import Vehiculo
from .schema import VehiculoCreate, VehiculoUpdate

UPLOAD_DIR = Path("static/fotos_vehiculos")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

EXTENSIONES_PERMITIDAS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_SIZE_BYTES = 5 * 1024 * 1024


def _get_or_404(db: Session, vehiculo_id: uuid.UUID) -> Vehiculo:
    v = db.query(Vehiculo).filter(Vehiculo.id == vehiculo_id).first()
    if not v:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")
    return v


def crear_vehiculo(db: Session, usuario_id: uuid.UUID, data: VehiculoCreate) -> Vehiculo:
    # Placa única por usuario
    existe = db.query(Vehiculo).filter(
        Vehiculo.usuario_id == usuario_id,
        Vehiculo.placa == data.placa.upper()
    ).first()
    if existe:
        raise HTTPException(status_code=409, detail="Ya tienes un vehículo con esa placa")

    vehiculo = Vehiculo(
        id=uuid.uuid4(),
        usuario_id=usuario_id,
        placa=data.placa.upper(),
        marca=data.marca,
        modelo=data.modelo,
        anio=data.anio,
        color=data.color,
        combustible=data.combustible,
    )
    db.add(vehiculo)
    db.commit()
    db.refresh(vehiculo)
    return vehiculo


def listar_mis_vehiculos(db: Session, usuario_id: uuid.UUID):
    return db.query(Vehiculo).filter(
        Vehiculo.usuario_id == usuario_id,
        Vehiculo.activo == True
    ).all()


def listar_todos(db: Session):
    return db.query(Vehiculo).all()


def obtener_vehiculo(db: Session, vehiculo_id: uuid.UUID) -> Vehiculo:
    return _get_or_404(db, vehiculo_id)


def actualizar_vehiculo(
    db: Session,
    vehiculo_id: uuid.UUID,
    data: VehiculoUpdate,
    usuario_id: uuid.UUID,
    es_admin: bool = False
) -> Vehiculo:
    v = _get_or_404(db, vehiculo_id)

    if not es_admin and str(v.usuario_id) != str(usuario_id):
        raise HTTPException(status_code=403, detail="No tienes permiso para modificar este vehículo")

    for campo, valor in data.model_dump(exclude_unset=True).items():
        if campo == "placa" and valor:
            valor = valor.upper()
        setattr(v, campo, valor)

    db.commit()
    db.refresh(v)
    return v


def eliminar_vehiculo(db: Session, vehiculo_id: uuid.UUID, usuario_id: uuid.UUID, es_admin: bool = False):
    v = _get_or_404(db, vehiculo_id)
    if not es_admin and str(v.usuario_id) != str(usuario_id):
        raise HTTPException(status_code=403, detail="No tienes permiso para eliminar este vehículo")
    v.activo = False
    db.commit()
    return {"detail": "Vehículo desactivado correctamente"}


async def subir_foto(
    db: Session,
    vehiculo_id: uuid.UUID,
    foto: UploadFile,
    base_url: str,
    usuario_id: uuid.UUID,
    es_admin: bool = False
) -> str:
    v = _get_or_404(db, vehiculo_id)
    if not es_admin and str(v.usuario_id) != str(usuario_id):
        raise HTTPException(status_code=403, detail="No tienes permiso")

    ext = Path(foto.filename).suffix.lower()
    if ext not in EXTENSIONES_PERMITIDAS:
        raise HTTPException(status_code=422, detail=f"Formato no permitido. Usa: {', '.join(EXTENSIONES_PERMITIDAS)}")

    contenido = await foto.read()
    if len(contenido) > MAX_SIZE_BYTES:
        raise HTTPException(status_code=413, detail="La imagen supera el límite de 5 MB")

    # Eliminar foto anterior
    if v.foto_url:
        try:
            ruta_anterior = Path(v.foto_url.replace(base_url + "/", ""))
            if ruta_anterior.exists():
                ruta_anterior.unlink(missing_ok=True)
        except Exception:
            pass

    nombre = f"{vehiculo_id}{ext}"
    (UPLOAD_DIR / nombre).write_bytes(contenido)

    url = f"{base_url}/static/fotos_vehiculos/{nombre}"
    v.foto_url = url
    db.commit()
    db.refresh(v)
    return url

