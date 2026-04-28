import uuid
from sqlalchemy import Column, String, DECIMAL, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
from datetime import datetime

class Pago(Base):
    __tablename__ = "pagos"

    id                  = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    asignacion_id       = Column(UUID(as_uuid=True), ForeignKey("asignaciones.id"), nullable=False)
    usuario_id          = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"),     nullable=False)
    monto_total         = Column(DECIMAL(10, 2),   nullable=False)
    comision_plataforma = Column(DECIMAL(10, 2),   nullable=False, default=0)
    monto_taller        = Column(DECIMAL(10, 2),   nullable=False, default=0)
    metodo              = Column(String(25),        nullable=False)   # efectivo | qr | tarjeta | transferencia
    estado              = Column(String(15),        nullable=False, default="pendiente")
    referencia_externa  = Column(String(200),       nullable=True)
    detalle_error       = Column(Text,              nullable=True)
    descripcion         = Column(Text,       nullable=True)   # descripción del servicio
    qr_imagen_url       = Column(Text,  nullable=True)   # URL de imagen QR
    comprobante_url     = Column(Text,       nullable=True)   # foto del comprobante
    pagado_at           = Column(DateTime,          nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    # Relaciones
    asignacion = relationship("Asignacion", backref="pagos")