from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database     import get_db
from app.dependencies import require_roles
from . import service, schema

router = APIRouter(prefix="/asignaciones", tags=["asignaciones"])


# ── CASOS DISPONIBLES ─────────────────────────────────────────────────────────

@router.get("/disponibles", response_model=list[schema.AsignacionOut])
def casos_disponibles(
    db:           Session = Depends(get_db),
    current_user          = Depends(require_roles("tecnico")),
):
    if not current_user.taller_id:
        raise HTTPException(status_code=400, detail="Técnico sin taller asignado")
    return service.get_casos_disponibles(db, current_user.taller_id)


# ── ACEPTAR CASO ──────────────────────────────────────────────────────────────
# ✅ async + await porque service.aceptar_caso es una coroutine

@router.patch("/{asignacion_id}/aceptar")
async def aceptar_caso(
    asignacion_id: UUID,
    db:            Session = Depends(get_db),
    current_user           = Depends(require_roles("tecnico")),
):
    resultado = await service.aceptar_caso(
        db, asignacion_id, current_user.id
    )
    if not resultado:
        raise HTTPException(status_code=409, detail="Este caso ya fue tomado")
    return {"mensaje": "Caso aceptado", "asignacion_id": str(resultado.id)}


# ── HISTORIAL DEL TÉCNICO ─────────────────────────────────────────────────────

@router.get("/mi-historial", response_model=list[schema.CasoHistorialOut])
def historial_tecnico(
    estado:      Optional[str] = Query(None, description="pendientes | proceso | terminados"),
    db:          Session       = Depends(get_db),
    current_user               = Depends(require_roles("tecnico")),
):
    return service.get_historial_tecnico(db, current_user.id, estado)


# ── CAMBIAR ESTADO ────────────────────────────────────────────────────────────
# ✅ async + await porque service.cambiar_estado es una coroutine

@router.patch("/{asignacion_id}/estado")
async def cambiar_estado(
    asignacion_id: UUID,
    data:          schema.CambiarEstadoRequest,
    db:            Session = Depends(get_db),
    current_user           = Depends(require_roles("tecnico")),
):
    resultado = await service.cambiar_estado(
        db                 = db,
        asignacion_id      = asignacion_id,
        nuevo_estado       = data.nuevo_estado,
        tecnico_usuario_id = current_user.id,
        nota               = data.nota,
    )
    return {
        "mensaje": f"Estado actualizado a '{resultado.estado}'",
        "estado":  resultado.estado,
    }