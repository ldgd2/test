import uuid
from sqlalchemy import Column, String, Boolean, Numeric, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base


class Taller(Base):
    __tablename__ = "talleres"

    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nombre            = Column(String(150),  nullable=False)
    email             = Column(String(150),  nullable=False, unique=True)
    password_hash     = Column(Text,         nullable=False)
    telefono          = Column(String(20),   nullable=True)
    direccion         = Column(Text,         nullable=True)
    latitud           = Column(Numeric(12, 9), nullable=True)
    longitud          = Column(Numeric(12, 9), nullable=True)
    radio_servicio_km = Column(Numeric(6, 2),  nullable=True, default=10)
    logo_url          = Column(Text,         nullable=True)
    descripcion       = Column(Text,         nullable=True)
    activo            = Column(Boolean,      nullable=False, default=True)
    verificado        = Column(Boolean,      nullable=False, default=False)
    comision_pct      = Column(Numeric(5, 2), nullable=False, default=10.00)

    # --- RELACIONES ---
    asignaciones = relationship("Asignacion", back_populates="taller")
    tecnicos     = relationship("Usuario",    back_populates="taller", foreign_keys="Usuario.taller_id")