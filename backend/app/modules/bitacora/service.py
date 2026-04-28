from sqlalchemy.orm import Session
from datetime import datetime
from app.modules.bitacora.models import Bitacora
from app.modules.usuarios.models import Usuario
import uuid

def registrar_accion(
    db: Session,
    usuario: Usuario,
    accion: str,   # 'login' | 'logout'
    ip: str = None
):
    registro = Bitacora(
        id=uuid.uuid4(),
        usuario_id=usuario.id,
        email=usuario.email,
        nombres=f"{usuario.nombres} {usuario.apellidos}",
        tipo=usuario.tipo,
        accion=accion,
        fecha_hora=datetime.utcnow(),
        ip=ip
    )
    db.add(registro)
    db.commit()

def listar_bitacora(db: Session):
    registros = db.query(Bitacora).order_by(Bitacora.fecha_hora.desc()).all()
    return {"total": len(registros), "registros": registros}