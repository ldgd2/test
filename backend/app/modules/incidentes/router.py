from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID

from app.dependencies import get_db, get_current_user
from . import service, schema

router = APIRouter(prefix="/incidentes", tags=["incidentes"])


# ─── CREAR INCIDENTE CON FOTO ───────────────────────────────────
@router.post("/", response_model=schema.IncidenteResponse)
async def crear_incidente(
    vehiculo_id: str = Form(...),
    categoria: str = Form(...),
    direccion_texto: str = Form(...),
    descripcion_manual: str = Form(...),
    ubicacion: str = Form("0,0"),
    prioridad: str = Form("media"),
    foto: UploadFile = File(None),   # foto opcional
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    return await service.create_incidente_completo(
        db=db,
        vehiculo_id=vehiculo_id,
        categoria=categoria,
        direccion_texto=direccion_texto,
        descripcion_manual=descripcion_manual,
        ubicacion=ubicacion,
        prioridad=prioridad,
        foto=foto,
        usuario_id=current_user.id,
    )


# ─── LISTAR INCIDENTES PENDIENTES ──────────────────────────────
@router.get("/pendientes", response_model=List[schema.IncidenteResponse])
def listar_pendientes(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.tipo not in ["tecnico", "admin"]:
        raise HTTPException(
            status_code=403,
            detail="No tiene permisos para ver incidentes pendientes",
        )
    return service.get_incidentes_pendientes(db)


# ─── SUBIR EVIDENCIA ADICIONAL A UN INCIDENTE ──────────────────
@router.post("/{incidente_id}/evidencias", response_model=schema.EvidenciaResponse)
async def subir_evidencia(
    incidente_id: UUID,
    foto: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_incidente = service.get_incidente_by_id(db, incidente_id)
    if not db_incidente:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")

    return await service.save_evidencia(db, incidente_id, foto)

@router.get("/{incidente_id}/detalle", response_model=schema.IncidenteDetalleResponse)
def obtener_detalle(
    incidente_id: UUID,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Retorna el incidente completo con datos del vehículo y del cliente."""
    return service.get_incidente_detalle(db, incidente_id)
 
@router.get("/test-ia")
async def test_ia():
    from . import service
    resultado = await service.analizar_incidente_con_ia(
        descripcion       = "El auto no enciende, hace un ruido al girar la llave",
        categoria_cliente = "motor",
        marca_vehiculo    = "Toyota",
        modelo_vehiculo   = "Corolla",
    )
    return resultado