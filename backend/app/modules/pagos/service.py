import uuid
import os
import shutil
from datetime import datetime
from decimal import Decimal

from fastapi import UploadFile, HTTPException
from sqlalchemy.orm import Session

from .models import Pago
from . import schema
from app.modules.asignaciones.models import Asignacion
from app.modules.incidentes.models   import Incidente
from app.modules.talleres.models     import Taller
from app.modules.usuarios.models     import Usuario

UPLOAD_COMPROBANTES = "static/comprobantes"


# ══════════════════════════════════════════════════════════════════════════
# TÉCNICO CREA EL COBRO — desde Angular
# El técnico indica monto, descripción y método de pago
# ══════════════════════════════════════════════════════════════════════════

async def crear_cobro(
    db:           Session,
    data:         schema.PagoCreate,
    tecnico_id:   str,
):
    # 1. Verificar que la asignación existe y está completada
    asignacion = db.query(Asignacion).filter(
        Asignacion.id == data.asignacion_id
    ).first()

    if not asignacion:
        raise HTTPException(status_code=404, detail="Asignación no encontrada")

    if asignacion.estado != "completada":
        raise HTTPException(
            status_code=400,
            detail="Solo se puede cobrar en asignaciones completadas"
        )

    # 2. Verificar que no tenga ya un pago pendiente
    pago_existente = db.query(Pago).filter(
        Pago.asignacion_id == data.asignacion_id,
        Pago.estado        == "pendiente",
    ).first()

    if pago_existente:
        raise HTTPException(
            status_code=400,
            detail="Ya existe un cobro pendiente para esta asignación"
        )

    # 3. Obtener datos del taller para calcular comisión
    taller = db.query(Taller).filter(
        Taller.id == asignacion.taller_id
    ).first()

    comision_pct        = float(taller.comision_pct or 10) / 100
    comision_plataforma = round(data.monto_total * comision_pct, 2)
    monto_taller        = round(data.monto_total - comision_plataforma, 2)

    # 4. Obtener el cliente (usuario_id del incidente)
    incidente = db.query(Incidente).filter(
        Incidente.id == asignacion.incidente_id
    ).first()

    # 5. Crear el pago
    pago = Pago(
        id                  = uuid.uuid4(),
        asignacion_id       = data.asignacion_id,
        usuario_id          = incidente.usuario_id,
        monto_total         = data.monto_total,
        comision_plataforma = comision_plataforma,
        monto_taller        = monto_taller,
        metodo              = data.metodo,
        estado              = "pendiente",
        descripcion         = data.descripcion,
        qr_imagen_url       = data.qr_imagen_url,
    )
    db.add(pago)
    db.commit()
    db.refresh(pago)

    # 6. Notificar al cliente
    try:
        from app.modules.notificaciones.service import notificar
        await notificar(
            db              = db,
            destinatario_id = str(incidente.usuario_id),
            titulo          = "💳 ¡Tienes un cobro pendiente!",
            cuerpo          = (
                f"{taller.nombre} cobró Bs {data.monto_total:.2f} "
                f"por: {data.descripcion}"
            ),
            datos_extra = {
                "evento":        "pago_pendiente",
                "pago_id":       str(pago.id),
                "asignacion_id": str(data.asignacion_id),
                "monto":         float(data.monto_total),
                "metodo":        data.metodo,
                "descripcion":   data.descripcion,
                "qr_imagen_url": data.qr_imagen_url or "",
                "taller":        taller.nombre,
            },
        )
    except Exception as e:
        print(f"⚠️ Error notificando pago: {e}")

    return pago


# ══════════════════════════════════════════════════════════════════════════
# CLIENTE CONFIRMA PAGO — desde Flutter
# ══════════════════════════════════════════════════════════════════════════

async def confirmar_pago(
    db:         Session,
    pago_id:    str,
    usuario_id: str,
    metodo:     str,
    referencia: str = None,
    comprobante: UploadFile = None,
):
    pago = db.query(Pago).filter(
        Pago.id        == pago_id,
        Pago.usuario_id == usuario_id,
        Pago.estado    == "pendiente",
    ).first()

    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado")

    # Guardar comprobante si lo subió
    comprobante_path = None
    if comprobante and comprobante.filename:
        os.makedirs(UPLOAD_COMPROBANTES, exist_ok=True)
        ext              = comprobante.filename.split(".")[-1]
        filename         = f"{uuid.uuid4()}.{ext}"
        comprobante_path = os.path.join(UPLOAD_COMPROBANTES, filename)
        with open(comprobante_path, "wb") as buffer:
            shutil.copyfileobj(comprobante.file, buffer)

    # Actualizar pago
    pago.estado             = "procesado"
    pago.metodo             = metodo
    pago.referencia_externa = referencia
    pago.comprobante_url    = comprobante_path
    pago.pagado_at          = datetime.utcnow()

    db.commit()
    db.refresh(pago)

    # Notificar al taller que el pago fue realizado
    try:
        asignacion = db.query(Asignacion).filter(
            Asignacion.id == pago.asignacion_id
        ).first()
        tecnico = db.query(Usuario).filter(
            Usuario.id == asignacion.usuario_id
        ).first()

        from app.modules.notificaciones.service import notificar
        if tecnico:
            await notificar(
                db              = db,
                destinatario_id = str(tecnico.id),
                titulo          = "✅ Pago recibido",
                cuerpo          = f"El cliente realizó el pago de Bs {float(pago.monto_total):.2f} por {metodo}",
                datos_extra     = {
                    "evento":   "pago_confirmado",
                    "pago_id":  str(pago.id),
                    "metodo":   metodo,
                    "monto":    float(pago.monto_total),
                },
                tipo = "tecnico",
            )
    except Exception as e:
        print(f"⚠️ Error notificando confirmación: {e}")

    return pago


# ══════════════════════════════════════════════════════════════════════════
# OBTENER PAGO POR ASIGNACIÓN
# ══════════════════════════════════════════════════════════════════════════

def get_pago_por_asignacion(db: Session, asignacion_id: str) -> schema.PagoDetalleOut:
    pago = db.query(Pago).filter(
        Pago.asignacion_id == asignacion_id
    ).first()

    if not pago:
        raise HTTPException(status_code=404, detail="No hay pago para esta asignación")

    # Info extra
    asignacion = db.query(Asignacion).filter(
        Asignacion.id == asignacion_id
    ).first()
    taller    = db.query(Taller).filter(
        Taller.id == asignacion.taller_id
    ).first() if asignacion else None
    tecnico   = db.query(Usuario).filter(
        Usuario.id == asignacion.usuario_id
    ).first() if asignacion else None
    incidente = db.query(Incidente).filter(
        Incidente.id == asignacion.incidente_id
    ).first() if asignacion else None

    return schema.PagoDetalleOut(
        id                    = pago.id,
        asignacion_id         = pago.asignacion_id,
        monto_total           = float(pago.monto_total),
        comision_plataforma   = float(pago.comision_plataforma),
        monto_taller          = float(pago.monto_taller),
        metodo                = pago.metodo,
        estado                = pago.estado,
        descripcion           = pago.descripcion,
        qr_imagen_url         = pago.qr_imagen_url,
        comprobante_url       = pago.comprobante_url,
        referencia_externa    = pago.referencia_externa,
        pagado_at             = pago.pagado_at,
        created_at            = pago.created_at,
        taller_nombre         = taller.nombre if taller else None,
        tecnico_nombre        = f"{tecnico.nombres} {tecnico.apellidos}" if tecnico else None,
        categoria             = incidente.categoria if incidente else None,
        descripcion_incidente = incidente.descripcion_manual if incidente else None,
    )


# ══════════════════════════════════════════════════════════════════════════
# MIS PAGOS (cliente)
# ══════════════════════════════════════════════════════════════════════════

def get_mis_pagos(db: Session, usuario_id: str):
    return db.query(Pago).filter(
        Pago.usuario_id == usuario_id
    ).order_by(Pago.created_at.desc()).all()