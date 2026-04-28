import uuid
from sqlalchemy import Column, String, SmallInteger, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base

class Vehiculo(Base):
    __tablename__ = "vehiculos"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    usuario_id  = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    placa       = Column(String(20),  nullable=False)
    marca       = Column(String(60),  nullable=False)
    modelo      = Column(String(60),  nullable=False)
    anio        = Column(SmallInteger, nullable=False)
    color       = Column(String(40),  nullable=True)
    combustible = Column(String(20),  nullable=False, default="gasolina")
    foto_url    = Column(String,      nullable=True)
    activo      = Column(Boolean,     nullable=False, default=True)

    usuario = relationship("Usuario", back_populates="vehiculos")
    incidentes = relationship("Incidente", back_populates="vehiculo")