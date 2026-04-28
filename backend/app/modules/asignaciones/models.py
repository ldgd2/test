from sqlalchemy import Column, String, ForeignKey, DECIMAL, Integer, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from app.database import Base
from sqlalchemy.sql import func
from sqlalchemy import DateTime


class Asignacion(Base):
    __tablename__ = "asignaciones"

    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    incidente_id = Column(UUID(as_uuid=True), ForeignKey("incidentes.id"), nullable=False)
    taller_id    = Column(UUID(as_uuid=True), ForeignKey("talleres.id"),   nullable=False)
    usuario_id   = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"),   nullable=True)

    estado              = Column(String(15),   nullable=False, default="propuesta")
    distancia_km        = Column(DECIMAL(8, 2),  nullable=True)
    tiempo_estimado_min = Column(Integer,         nullable=True)
    precio_cotizado     = Column(DECIMAL(10, 2),  nullable=True)
    nota_taller         = Column(Text,            nullable=True)
    score_asignacion    = Column(DECIMAL(6, 4),   nullable=True)

    aceptado_at   = Column(DateTime, nullable=True)
    iniciado_at   = Column(DateTime, nullable=True)
    completado_at = Column(DateTime, nullable=True)
    created_at    = Column(DateTime, server_default=func.now())

    # ── RELACIONES ──
    incidente  = relationship("Incidente",          back_populates="asignaciones")
    taller     = relationship("Taller",             back_populates="asignaciones")
    tecnico    = relationship("Usuario",            back_populates="asignaciones_aceptadas")
    historial  = relationship("HistorialAsignacion", back_populates="asignacion",
                              cascade="all, delete-orphan")


class HistorialAsignacion(Base):
    __tablename__ = "historial_asignacion"

    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    asignacion_id = Column(UUID(as_uuid=True), ForeignKey("asignaciones.id", ondelete="CASCADE"),
                           nullable=False)
    estado_anterior = Column(String(15), nullable=True)
    estado_nuevo    = Column(String(15), nullable=False)
    cambiado_por    = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=True)
    fuente          = Column(String(50), default="sistema")
    nota            = Column(Text, nullable=True)
    created_at      = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # ── RELACIONES ──
    asignacion = relationship("Asignacion", back_populates="historial")
    usuario    = relationship("Usuario",    foreign_keys=[cambiado_por])