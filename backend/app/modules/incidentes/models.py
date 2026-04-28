from sqlalchemy import Column, String, ForeignKey, DECIMAL, Boolean, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
from app.database import Base
from sqlalchemy.sql import func


class Incidente(Base):
    __tablename__ = "incidentes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=False)
    vehiculo_id = Column(UUID(as_uuid=True), ForeignKey("vehiculos.id"), nullable=False)

    # Geolocalización y dirección
    direccion_texto = Column(String(500))
    ubicacion = Column(String(100))  # Formato "lat,long"
    descripcion_manual = Column(String(1000))

    # Clasificación
    categoria = Column(String(30), default="incierto")
    prioridad = Column(String(10), default="media")
    estado = Column(String(15), default="pendiente")

    # Resultados opcionales de IA
    resumen_ia = Column(String(1000), nullable=True)
    confianza_ia = Column(DECIMAL(5, 4), nullable=True)
    requiere_revision = Column(Boolean, default=False)

    # Foto principal del incidente
    foto_evidencia = Column(Text, nullable=True)

    created_at = Column(DateTime, server_default=func.now())

   
    usuario   = relationship("Usuario",            back_populates="incidentes")
    vehiculo  = relationship("Vehiculo",           back_populates="incidentes")
    evidencias = relationship("EvidenciaIncidente", back_populates="incidente")
    asignaciones = relationship("Asignacion",      back_populates="incidente")  # ← AGREGAR ESTA

class EvidenciaIncidente(Base):
    __tablename__ = "evidencia_incidentes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    incidente_id = Column(UUID(as_uuid=True), ForeignKey("incidentes.id"), nullable=False)

    ruta_foto = Column(String(255), nullable=False)
    descripcion = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    incidente = relationship("Incidente", back_populates="evidencias")