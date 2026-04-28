import uuid
import json
from sqlalchemy.orm import Session
from .models import Notificacion
from app.core.websocket_manager import ws_manager


async def notificar(
    db:              Session,
    destinatario_id: str,
    titulo:          str,
    cuerpo:          str,
    datos_extra:     dict = None,
    tipo:            str  = "cliente",
):
    """Guarda en BD, envía por WebSocket y por FCM push."""

    # 1. Guardar en BD
    notif = Notificacion(
        id                = uuid.uuid4(),
        destinatario_id   = destinatario_id,
        tipo_destinatario = tipo,
        titulo            = titulo,
        cuerpo            = cuerpo,
        datos_extra       = json.dumps(datos_extra) if datos_extra else None,
        leida             = False,
    )
    db.add(notif)
    db.commit()

    # 2. Enviar por WebSocket (app abierta)
    await ws_manager.enviar_a_usuario(str(destinatario_id), {
        "tipo":        "notificacion",
        "titulo":      titulo,
        "cuerpo":      cuerpo,
        "datos_extra": datos_extra or {},
        "notif_id":    str(notif.id),
    })

    # 3. Enviar por FCM (app cerrada/segundo plano)
    try:
        from app.modules.usuarios.models import Usuario
        from app.core.fcm_service        import enviar_push

        usuario = db.query(Usuario).filter(
            Usuario.id == destinatario_id
        ).first()

        if usuario and usuario.fcm_token:
            enviar_push(
                fcm_token = usuario.fcm_token,
                titulo    = titulo,
                cuerpo    = cuerpo,
                datos     = datos_extra or {},
            )
    except Exception as e:
        print(f"⚠️ Error enviando FCM: {e}")

    return notif


# ── EVENTOS ESPECÍFICOS ────────────────────────────────

async def notif_incidente_creado(db, cliente_id: str, talleres_ids: list):
    """Al crear incidente → avisar a todos los talleres."""
    from app.core.websocket_manager import ws_manager
    mensaje = {
        "tipo":   "nuevo_caso",
        "titulo": "🚨 Nuevo caso disponible",
        "cuerpo": "Hay un nuevo incidente vehicular en tu zona.",
    }
    await ws_manager.broadcast_talleres(
        [str(t) for t in talleres_ids], mensaje
    )


async def notif_taller_acepto(
    db, cliente_id: str, tecnico_nombre: str,
    taller_nombre: str, distancia_km: float, tiempo_min: int,
    asignacion_id: str,
):
    """Técnico acepta → avisar al cliente."""
    await notificar(
        db            = db,
        destinatario_id = str(cliente_id),
        titulo        = "✅ ¡Tu auxilio fue aceptado!",
        cuerpo        = (
            f"{tecnico_nombre} de {taller_nombre} aceptó tu caso. "
            f"Está a {distancia_km:.1f} km — llegará en aprox. {tiempo_min} minutos."
        ),
        datos_extra   = {
            "evento":        "aceptado",
            "asignacion_id": asignacion_id,
            "tecnico":       tecnico_nombre,
            "taller":        taller_nombre,
            "distancia_km":  distancia_km,
            "tiempo_min":    tiempo_min,
        },
    )


async def notif_tecnico_en_camino(
    db, cliente_id: str, tecnico_nombre: str, tiempo_min: int, asignacion_id: str
):
    """Técnico sale → avisar al cliente."""
    await notificar(
        db              = db,
        destinatario_id = str(cliente_id),
        titulo          = "🚗 El técnico está en camino",
        cuerpo          = f"{tecnico_nombre} salió hacia tu ubicación. Llegará en ~{tiempo_min} minutos.",
        datos_extra     = {
            "evento":        "en_camino",
            "asignacion_id": asignacion_id,
            "tiempo_min":    tiempo_min,
        },
    )


async def notif_servicio_completado(
    db, cliente_id: str, taller_nombre: str,
    precio: float, asignacion_id: str,
):
    """Servicio terminado → enviar monto a pagar."""
    await notificar(
        db              = db,
        destinatario_id = str(cliente_id),
        titulo          = "🔧 Servicio completado — Procede al pago",
        cuerpo          = f"{taller_nombre} completó el servicio. Total a pagar: Bs {precio:.2f}",
        datos_extra     = {
            "evento":        "pago_pendiente",
            "asignacion_id": asignacion_id,
            "monto":         precio,
            "taller":        taller_nombre,
        },
    )