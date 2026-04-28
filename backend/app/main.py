from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.modules.incidentes.router import router as incidentes_router
from app.modules.asignaciones.router import router as asignaciones_router
from app.modules.usuarios.router import router as usuarios_router
from app.modules.bitacora.router import router as bitacora_router
from app.modules.vehiculos.router import router as vehiculos_router
from app.database import engine
from app.modules.talleres.router import router as talleres_router
from app.modules.pagos.router import router as pagos_router
# main.py
from app.modules.incidentes.router import router as incidentes_router

from app.modules.notificaciones.router import router as notificaciones_router



app = FastAPI(
    title="Taller API",
    description="Backend para sistema de asistencia vehicular",
    version="1.0.0"
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(usuarios_router, prefix="/api")
app.include_router(bitacora_router, prefix="/api")
app.include_router(vehiculos_router, prefix="/api")
app.include_router(incidentes_router,prefix="/api")
app.include_router(talleres_router, prefix="/api")
app.include_router(asignaciones_router,prefix="/api")
app.include_router( notificaciones_router,prefix="/api/notificaciones",tags=["notificaciones"])
app.include_router(pagos_router, prefix="/api")

# ── Archivos estáticos (fotos de perfil) ──────────────────────────────────────
app.mount("/static", StaticFiles(directory="static"), name="static")

# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/")
def root():
    return {"status": "ok", "message": "Taller API corriendo"}

import os
os.makedirs("static/fotos_vehiculos", exist_ok=True)

# En el arranque agregar carpeta:
os.makedirs("static/logos_talleres", exist_ok=True)


# Test de conexión BD al arrancar
try:
    with engine.connect() as conn:
        print("✅ BASE DE DATOS CONECTADA")
except Exception as e:
    print(f"❌ ERROR BD: {e}")


    



