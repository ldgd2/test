from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from app.dependencies import get_db
from app.core.websocket_manager import ws_manager
from .models import Notificacion
import json

router = APIRouter()


@router.websocket("/ws/{usuario_id}")
async def websocket_endpoint(websocket: WebSocket, usuario_id: str):
    await ws_manager.conectar(websocket, usuario_id)
    try:
        while True:
            # Mantener conexión viva
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.desconectar(websocket, usuario_id)


@router.get("/mis-notificaciones")
def get_mis_notificaciones(
    db:          Session = Depends(get_db),
    usuario_id:  str     = None,
):
    return db.query(Notificacion)\
             .filter(Notificacion.destinatario_id == usuario_id)\
             .order_by(Notificacion.created_at.desc())\
             .limit(20).all()


@router.patch("/{notif_id}/leida")
def marcar_leida(notif_id: str, db: Session = Depends(get_db)):
    notif = db.query(Notificacion).filter(Notificacion.id == notif_id).first()
    if notif:
        notif.leida = True
        db.commit()
    return {"ok": True}