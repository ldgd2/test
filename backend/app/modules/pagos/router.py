from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, UploadFile, File, Form
from sqlalchemy.orm import Session

from app.database     import get_db
from app.dependencies import get_current_user, require_roles
from . import service, schema

router = APIRouter(prefix="/pagos", tags=["pagos"])


# ── TÉCNICO CREA COBRO — Angular ──────────────────────────────────────────
# El técnico envía el formulario de cobro al cliente

@router.post("/cobrar", response_model=schema.PagoOut)
async def crear_cobro(
    data:        schema.PagoCreate,
    db:          Session = Depends(get_db),
    current_user         = Depends(require_roles("tecnico")),
):
    return await service.crear_cobro(
        db         = db,
        data       = data,
        tecnico_id = str(current_user.id),
    )


# ── CLIENTE VE EL PAGO DE SU ASIGNACIÓN — Flutter ────────────────────────

@router.get("/asignacion/{asignacion_id}", response_model=schema.PagoDetalleOut)
def get_pago_asignacion(
    asignacion_id: UUID,
    db:            Session = Depends(get_db),
    current_user           = Depends(get_current_user),
):
    return service.get_pago_por_asignacion(db, str(asignacion_id))


# ── CLIENTE CONFIRMA PAGO — Flutter ──────────────────────────────────────

@router.patch("/{pago_id}/confirmar")
async def confirmar_pago(
    pago_id:    UUID,
    metodo:     str        = Form(...),
    referencia: str        = Form(None),
    comprobante: UploadFile = File(None),
    db:          Session   = Depends(get_db),
    current_user           = Depends(get_current_user),
):
    return await service.confirmar_pago(
        db          = db,
        pago_id     = str(pago_id),
        usuario_id  = str(current_user.id),
        metodo      = metodo,
        referencia  = referencia,
        comprobante = comprobante,
    )


# ── MIS PAGOS (cliente ve historial) ─────────────────────────────────────

@router.get("/mis-pagos", response_model=list[schema.PagoOut])
def mis_pagos(
    db:          Session = Depends(get_db),
    current_user         = Depends(get_current_user),
):
    return service.get_mis_pagos(db, str(current_user.id))