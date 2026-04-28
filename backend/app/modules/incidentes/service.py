import os
import shutil
import uuid
import base64
import json
import httpx
from uuid import UUID
from typing import List, Optional

from fastapi import UploadFile
from sqlalchemy.orm import Session

from . import models, schema
from .models import Incidente
from .schema import IncidenteCreate
from app.core.config import settings

# ══════════════════════════════════════════════════════
# CONFIGURACIÓN OPENROUTER
# ══════════════════════════════════════════════════════

UPLOAD_FOLDER    = "static/evidencias"
OPENROUTER_URL   = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_KEY   = settings.OPENROUTER_API_KEY
OPENROUTER_MODEL = "meta-llama/llama-3.1-8b-instruct:free"


# ══════════════════════════════════════════════════════
# ANÁLISIS DE IA CON OPENROUTER
# ══════════════════════════════════════════════════════

async def analizar_incidente_con_ia(
    descripcion:       str,
    categoria_cliente: str,
    marca_vehiculo:    str = "",
    modelo_vehiculo:   str = "",
    foto_path:         str = None,
) -> dict:

    print("🤖 Analizando incidente con OpenRouter...")

    prompt = f"""Eres un mecánico experto. Analiza este reporte de emergencia vehicular y responde SOLO en JSON válido.

Vehículo: {marca_vehiculo} {modelo_vehiculo}
Categoría reportada: {categoria_cliente}
Descripción del cliente: {descripcion}

Responde ÚNICAMENTE con este JSON (sin texto extra, sin markdown):
{{
  "resumen": "diagnóstico técnico en 2-3 oraciones",
  "categoria": "{categoria_cliente}",
  "prioridad": "baja|media|alta|critica",
  "confianza": 0.00
}}"""

    headers = {
        "Authorization": f"Bearer {OPENROUTER_KEY}",
        "Content-Type":  "application/json",
        "HTTP-Referer":  "http://localhost:4200",
        "X-Title":       "AutoEmergencias",
    }

    body = {
        "model":       OPENROUTER_MODEL,
        "messages":    [{"role": "user", "content": prompt}],
        "temperature": 0.3,
        "max_tokens":  300,
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(OPENROUTER_URL, headers=headers, json=body)

        if response.status_code != 200:
            print(f"⚠️ Error OpenRouter {response.status_code}: {response.text}")
            return _resultado_fallback(categoria_cliente, descripcion, marca_vehiculo, modelo_vehiculo)

        data  = response.json()
        texto = data["choices"][0]["message"]["content"].strip()

        # Limpiar si viene con bloques markdown
        if "```" in texto:
            texto = texto.split("```")[1]
            if texto.startswith("json"):
                texto = texto[4:]

        resultado = json.loads(texto)

        print(f"✅ OpenRouter analizó: prioridad={resultado.get('prioridad')}, confianza={resultado.get('confianza')}")

        return {
            "resumen_ia":        resultado.get("resumen", ""),
            "categoria":         resultado.get("categoria", categoria_cliente),
            "prioridad":         resultado.get("prioridad", "media"),
            "confianza_ia":      float(resultado.get("confianza", 0.70)),
            "requiere_revision": float(resultado.get("confianza", 0.70)) < 0.6,
        }

    except Exception as e:
        print(f"⚠️ Error OpenRouter: {e}")
        return _resultado_fallback(categoria_cliente, descripcion, marca_vehiculo, modelo_vehiculo)


def _resultado_fallback(categoria: str, descripcion: str, marca: str = "", modelo: str = "") -> dict:
    analisis = {
        "bateria":            ("Posible batería descargada o alternador defectuoso. Verificar voltaje y bornes.", "alta",    0.75),
        "llanta":             ("Desinflado o daño en llanta. No circular para evitar daño al aro.",              "alta",    0.90),
        "motor":              ("Falla en motor detectada. Diagnóstico computarizado recomendado.",               "alta",    0.70),
        "sobrecalentamiento": ("URGENTE: Apagar motor. Revisar refrigerante, termostato y radiador.",            "critica", 0.92),
        "choque":             ("Impacto detectado. Evaluar daños estructurales y sistema de frenos.",            "alta",    0.85),
        "llave_perdida":      ("Pérdida de llave. Cerrajero automotriz para apertura y duplicado.",              "media",   0.95),
        "llave_adentro":      ("Llaves en interior. Apertura de emergencia sin daños necesaria.",               "media",   0.95),
    }
    resumen, prioridad, confianza = analisis.get(categoria, (
        f"Problema no identificado: {descripcion[:80]}. Inspección manual requerida.", "media", 0.50
    ))
    return {
        "resumen_ia":        f"El {marca} {modelo}: {resumen}",
        "categoria":         categoria,
        "prioridad":         prioridad,
        "confianza_ia":      confianza,
        "requiere_revision": confianza < 0.6,
    }


# ══════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════

def _guardar_foto(foto: UploadFile) -> str:
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    ext       = foto.filename.split(".")[-1]
    filename  = f"{uuid.uuid4()}.{ext}"
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(foto.file, buffer)
    return file_path


def _distancia_haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    import math
    R     = 6371
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a     = (math.sin(d_lat / 2) ** 2 +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(d_lng / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _crear_asignaciones_para_incidente(db: Session, incidente: Incidente) -> None:
    from app.modules.talleres.models     import Taller
    from app.modules.asignaciones.models import Asignacion

    lat_inc, lng_inc = None, None
    if incidente.ubicacion:
        try:
            partes  = incidente.ubicacion.split(",")
            lat_inc = float(partes[0].strip())
            lng_inc = float(partes[1].strip())
        except Exception:
            pass

    talleres: List[Taller] = db.query(Taller).filter(Taller.activo == True).all()

    for taller in talleres:
        distancia_km = None

        if lat_inc and lng_inc and taller.latitud and taller.longitud:
            distancia_km = _distancia_haversine(
                lat_inc, lng_inc,
                float(taller.latitud), float(taller.longitud),
            )
            radio = float(taller.radio_servicio_km or 10)
            if distancia_km > radio:
                continue

        asignacion = Asignacion(
            id           = uuid.uuid4(),
            incidente_id = incidente.id,
            taller_id    = taller.id,
            usuario_id   = None,
            estado       = "propuesta",
            distancia_km = distancia_km,
        )
        db.add(asignacion)

    db.commit()


# ══════════════════════════════════════════════════════
# CREAR INCIDENTE COMPLETO — con análisis IA
# ══════════════════════════════════════════════════════

async def create_incidente_completo(
    db:                 Session,
    vehiculo_id:        str,
    categoria:          str,
    direccion_texto:    str,
    descripcion_manual: str,
    ubicacion:          str,
    prioridad:          str,
    foto:               UploadFile,
    usuario_id:         str,
):
    # 1. Guardar foto si existe
    foto_path = None
    if foto is not None and foto.filename:
        foto_path = _guardar_foto(foto)

    # 2. Obtener datos del vehículo para el contexto de la IA
    from app.modules.vehiculos.models import Vehiculo
    vehiculo = db.query(Vehiculo).filter(Vehiculo.id == vehiculo_id).first()
    marca_v  = vehiculo.marca  if vehiculo else ""
    modelo_v = vehiculo.modelo if vehiculo else ""

    # 3. Analizar con OpenRouter IA
    resultado_ia = await analizar_incidente_con_ia(
        descripcion       = descripcion_manual,
        categoria_cliente = categoria,
        marca_vehiculo    = marca_v,
        modelo_vehiculo   = modelo_v,
        foto_path         = foto_path,
    )

    # 4. Crear el incidente con datos de la IA
    db_incidente = Incidente(
        usuario_id         = usuario_id,
        vehiculo_id        = vehiculo_id,
        categoria          = resultado_ia["categoria"],
        direccion_texto    = direccion_texto,
        descripcion_manual = descripcion_manual,
        ubicacion          = ubicacion,
        prioridad          = resultado_ia["prioridad"],
        estado             = "pendiente",
        foto_evidencia     = foto_path,
        resumen_ia         = resultado_ia["resumen_ia"],
        confianza_ia       = resultado_ia["confianza_ia"],
        requiere_revision  = resultado_ia["requiere_revision"],
    )
    db.add(db_incidente)
    db.commit()
    db.refresh(db_incidente)

    # 5. Crear asignaciones para talleres cercanos
    _crear_asignaciones_para_incidente(db, db_incidente)

    return db_incidente


# ══════════════════════════════════════════════════════
# RESTO DE FUNCIONES CRUD
# ══════════════════════════════════════════════════════

def create_incidente(db: Session, incidente: IncidenteCreate, usuario_id: str):
    db_incidente = Incidente(
        **incidente.dict(),
        usuario_id = usuario_id,
        estado     = "pendiente",
    )
    db.add(db_incidente)
    db.commit()
    db.refresh(db_incidente)
    _crear_asignaciones_para_incidente(db, db_incidente)
    return db_incidente


def get_incidentes_pendientes(db: Session):
    return db.query(Incidente).filter(Incidente.estado == "pendiente").all()


def get_incidente_by_id(db: Session, incidente_id: UUID):
    return db.query(Incidente).filter(Incidente.id == incidente_id).first()


async def save_evidencia(db: Session, incidente_id: UUID, foto: UploadFile):
    file_path       = _guardar_foto(foto)
    nueva_evidencia = models.EvidenciaIncidente(
        incidente_id = incidente_id,
        ruta_foto    = file_path,
    )
    db.add(nueva_evidencia)
    db.commit()
    db.refresh(nueva_evidencia)
    return nueva_evidencia


def get_incidente_detalle(db: Session, incidente_id: UUID):
    from app.modules.vehiculos.models    import Vehiculo
    from app.modules.usuarios.models     import Usuario
    from app.modules.asignaciones.models import Asignacion
    from fastapi import HTTPException

    incidente = db.query(Incidente).filter(Incidente.id == incidente_id).first()
    if not incidente:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")

    vehiculo   = db.query(Vehiculo).filter(Vehiculo.id == incidente.vehiculo_id).first()
    cliente    = db.query(Usuario).filter(Usuario.id   == incidente.usuario_id).first()
    asignacion = db.query(Asignacion).filter(
        Asignacion.incidente_id == incidente.id,
        Asignacion.estado       == "propuesta",
    ).first()

    return {
        "id":                 incidente.id,
        "descripcion_manual": incidente.descripcion_manual,
        "categoria":          incidente.categoria,
        "prioridad":          incidente.prioridad,
        "estado":             incidente.estado,
        "direccion_texto":    incidente.direccion_texto,
        "ubicacion":          incidente.ubicacion,
        "foto_evidencia":     incidente.foto_evidencia,
        # ── CAMPOS IA ──
        "resumen_ia":         incidente.resumen_ia,
        "confianza_ia":       float(incidente.confianza_ia) if incidente.confianza_ia else None,
        "requiere_revision":  incidente.requiere_revision,
        "distancia_km":       float(asignacion.distancia_km) if asignacion and asignacion.distancia_km else None,
        "created_at":         incidente.created_at,
        "vehiculo": {
            "placa":  vehiculo.placa,
            "marca":  vehiculo.marca,
            "modelo": vehiculo.modelo,
            "anio":   vehiculo.anio,
            "color":  vehiculo.color,
        } if vehiculo else None,
        "cliente": {
            "nombres":   cliente.nombres,
            "apellidos": cliente.apellidos,
            "telefono":  cliente.telefono,
            "email":     cliente.email,
        } if cliente else None,
    }