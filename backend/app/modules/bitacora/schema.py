from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import List

class BitacoraOut(BaseModel):
    id:         UUID
    usuario_id: UUID
    email:      str
    nombres:    str
    tipo:       str
    accion:     str
    fecha_hora: datetime
    ip:         str | None = None

    model_config = {"from_attributes": True}

class BitacoraListOut(BaseModel):
    total:    int
    registros: List[BitacoraOut]