from uuid import UUID
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import and_
from fastapi import HTTPException

from . import models, schema
from ..incidentes.models import Incidente
from ..vehiculos.models import Vehiculo
from app.modules.usuarios.models import Usuario
from app.modules.talleres.models import Taller
from app.modules.notificaciones.service import (
    notif_taller_acepto,
    notif_tecnico_en_camino,
    notif_servicio_completado,
)

# ══════════════════════════════════════════════════
# HELPER — registrar cambio en historial_asignacion
# ══════════════════════════════════════════════════

def _registrar_historial(
    db: Session,
    asignacion_id: UUID,
    estado_anterior: str,
    estado_nuevo: str,
    cambiado_por: UUID = None,
    fuente: str = "tecnico",
    nota: str = None,
):
    registro = models.HistorialAsignacion(
        asignacion_id   = asignacion_id,
        estado_anterior = estado_anterior,
        estado_nuevo    = estado_nuevo,
        cambiado_por    = cambiado_por,
        fuente          = fuente,
        nota            = nota,
    )
    db.add(registro)


# ══════════════════════════════════════════════════
# CASOS DISPONIBLES (propuesta, sin técnico)
# ══════════════════════════════════════════════════

def get_casos_disponibles(db: Session, taller_id: UUID):
    rows = (
        db.query(models.Asignacion, Incidente, Vehiculo)
        .join(Incidente, Incidente.id == models.Asignacion.incidente_id)
        .join(Vehiculo,  Vehiculo.id  == Incidente.vehiculo_id)
        .filter(
            and_(
                models.Asignacion.taller_id  == taller_id,
                models.Asignacion.estado     == "propuesta",
                models.Asignacion.usuario_id == None,
            )
        )
        .all()
    )

    resultado = []
    for asig, inc, veh in rows:
        resultado.append(schema.AsignacionOut(
            asignacion_id       = asig.id,
            incidente_id        = asig.incidente_id,
            estado              = asig.estado,
            distancia_km        = float(asig.distancia_km) if asig.distancia_km else None,
            tiempo_estimado_min = asig.tiempo_estimado_min,
            precio_cotizado     = float(asig.precio_cotizado) if asig.precio_cotizado else None,
            nota_taller         = asig.nota_taller,
            created_at          = asig.created_at,
            descripcion_manual  = inc.descripcion_manual,
            direccion_texto     = inc.direccion_texto,
            categoria           = inc.categoria,
            prioridad           = inc.prioridad,
            placa               = veh.placa,
            marca_vehiculo      = veh.marca,
            modelo_vehiculo     = veh.modelo,
            color_vehiculo      = veh.color,
        ))
    return resultado


# ══════════════════════════════════════════════════
# ACEPTAR CASO
# ══════════════════════════════════════════════════

async def aceptar_caso(db: Session, asignacion_id: UUID, tecnico_usuario_id: UUID):
    # 1. Obtener asignación con sus relaciones para la notificación
    asignacion = db.query(models.Asignacion).filter(
        models.Asignacion.id     == asignacion_id,
        models.Asignacion.estado == "propuesta"
    ).first()

    if not asignacion:
        return None  # Ya fue tomado por otro técnico

    # 2. Obtener datos extra para notificaciones
    incidente = db.query(Incidente).filter(Incidente.id == asignacion.incidente_id).first()
    tecnico = db.query(Usuario).filter(Usuario.id == tecnico_usuario_id).first()
    taller = db.query(Taller).filter(Taller.id == asignacion.taller_id).first()

    # 3. Actualizar estado
    estado_anterior = asignacion.estado
    asignacion.estado = "aceptada"
    asignacion.usuario_id = tecnico_usuario_id
    asignacion.aceptado_at = datetime.utcnow()

    # 4. Registrar historial
    _registrar_historial(
        db              = db,
        asignacion_id   = asignacion.id,
        estado_anterior = estado_anterior,
        estado_nuevo    = "aceptada",
        cambiado_por    = tecnico_usuario_id,
        fuente          = "tecnico",
        nota            = "Caso aceptado por el técnico",
    )

    db.commit()
    db.refresh(asignacion)

    # 5. Notificar al Cliente
    tiempo_min = int((asignacion.distancia_km or 5) * 4)  # ~4 min por km
    await notif_taller_acepto(
        db             = db,
        cliente_id     = incidente.usuario_id,
        tecnico_nombre = f"{tecnico.nombres} {tecnico.apellidos}",
        taller_nombre  = taller.nombre,
        distancia_km   = float(asignacion.distancia_km or 0),
        tiempo_min     = tiempo_min,
        asignacion_id  = str(asignacion.id),
    )

    return asignacion


# ══════════════════════════════════════════════════
# CAMBIAR ESTADO DE UNA ASIGNACIÓN
# ══════════════════════════════════════════════════

TRANSICIONES_VALIDAS = {
    "aceptada":   ["en_camino", "cancelada"],
    "en_camino":  ["completada", "cancelada"],
}

async def cambiar_estado(db: Session, asignacion_id: UUID, nuevo_estado: str, tecnico_usuario_id: UUID, nota: str = None):
    # 1. Buscar asignación
    asignacion = db.query(models.Asignacion).filter(
        models.Asignacion.id         == asignacion_id,
        models.Asignacion.usuario_id == tecnico_usuario_id,
    ).first()

    if not asignacion:
        raise HTTPException(status_code=404, detail="Asignación no encontrada o no pertenece al técnico")

    # 2. Validar transición
    estados_permitidos = TRANSICIONES_VALIDAS.get(asignacion.estado, [])
    if nuevo_estado not in estados_permitidos:
        raise HTTPException(
            status_code=400,
            detail=f"No puedes pasar de '{asignacion.estado}' a '{nuevo_estado}'"
        )

    # 3. Preparar datos para notificaciones
    incidente = db.query(Incidente).filter(Incidente.id == asignacion.incidente_id).first()
    tecnico = db.query(Usuario).filter(Usuario.id == tecnico_usuario_id).first()
    taller = db.query(Taller).filter(Taller.id == asignacion.taller_id).first()

    estado_anterior = asignacion.estado
    historial_nuevo_estado = nuevo_estado # Backup para el log

    # 4. Lógica de negocio por estado
    if nuevo_estado == "en_camino":
        asignacion.estado = "en_camino"
        asignacion.iniciado_at = datetime.utcnow()
        
        tiempo_min = int((asignacion.distancia_km or 5) * 4)
        await notif_tecnico_en_camino(
            db, incidente.usuario_id,
            f"{tecnico.nombres}", tiempo_min, str(asignacion_id)
        )

    elif nuevo_estado == "completada":
        asignacion.estado = "completada"
        asignacion.completado_at = datetime.utcnow()
        
        await notif_servicio_completado(
            db, incidente.usuario_id,
            taller.nombre,
            float(asignacion.precio_cotizado or 0),
            str(asignacion_id),
        )

    elif nuevo_estado == "cancelada":
        # Devolver el caso al pool de propuestas
        asignacion.estado     = "propuesta"
        asignacion.usuario_id = None
        asignacion.aceptado_at = None
        asignacion.iniciado_at = None
        historial_nuevo_estado = "propuesta" # Para reflejar la liberación en el log

    # 5. Guardar historial y DB
    _registrar_historial(
        db              = db,
        asignacion_id   = asignacion.id,
        estado_anterior = estado_anterior,
        estado_nuevo    = historial_nuevo_estado,
        cambiado_por    = tecnico_usuario_id,
        fuente          = "tecnico",
        nota            = nota,
    )

    db.commit()
    db.refresh(asignacion)
    return asignacion


# ══════════════════════════════════════════════════
# HISTORIAL DEL TÉCNICO
# ══════════════════════════════════════════════════

def get_historial_tecnico(db: Session, tecnico_usuario_id: UUID, estado: str = None):
    query = (
        db.query(models.Asignacion, Incidente, Vehiculo)
        .join(Incidente, Incidente.id == models.Asignacion.incidente_id)
        .join(Vehiculo,  Vehiculo.id  == Incidente.vehiculo_id)
        .filter(models.Asignacion.usuario_id == tecnico_usuario_id)
    )

    if estado == "pendientes":
        query = query.filter(models.Asignacion.estado == "aceptada")
    elif estado == "proceso":
        query = query.filter(models.Asignacion.estado == "en_camino")
    elif estado == "terminados":
        query = query.filter(models.Asignacion.estado.in_(["completada", "cancelada"]))

    rows = query.order_by(models.Asignacion.created_at.desc()).all()

    resultado = []
    for asig, inc, veh in rows:
        resultado.append(schema.CasoHistorialOut(
            asignacion_id       = asig.id,
            incidente_id        = asig.incidente_id,
            estado              = asig.estado,
            categoria           = inc.categoria,
            prioridad           = inc.prioridad,
            descripcion_manual  = inc.descripcion_manual,
            direccion_texto     = inc.direccion_texto,
            distancia_km        = float(asig.distancia_km) if asig.distancia_km else None,
            precio_cotizado     = float(asig.precio_cotizado) if asig.precio_cotizado else None,
            foto_evidencia      = inc.foto_evidencia,
            aceptado_at         = asig.aceptado_at,
            completado_at       = asig.completado_at,
            created_at          = asig.created_at,
            resumen_ia          = inc.resumen_ia,
            confianza_ia        = float(inc.confianza_ia) if inc.confianza_ia else None,
            requiere_revision   = inc.requiere_revision,
            vehiculo = schema.VehiculoResumen(
                placa  = veh.placa,
                marca  = veh.marca,
                modelo = veh.modelo,
                color  = veh.color,
            ) if veh else None,
        ))
    return resultado