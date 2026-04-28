#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   BACKEND — 02 Inicializar Base de Datos (PostgreSQL)           ║
# ║   Crea todas las tablas vía SQLAlchemy                          ║
# ║   Uso: bash backend/02_init_db.sh [--reset]                     ║
# ║         --reset → elimina y recrea todas las tablas (cuidado!)  ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' NC='\033[0m'
log()     { echo -e "${C}[BACKEND]${NC} $*"; }
success() { echo -e "${G}[  OK  ]${NC} $*"; }
warn()    { echo -e "${Y}[ WARN ]${NC} $*"; }
error()   { echo -e "${R}[ ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKEND_DIR="$PROJECT_DIR/backend"
RESET=false

while [[ $# -gt 0 ]]; do
    case "$1" in --reset) RESET=true; shift ;; *) shift ;; esac
done

[ -f "$BACKEND_DIR/.env" ] || error ".env no encontrado. Ejecuta primero: bash deploy/configure_env.sh"
[ -f "$BACKEND_DIR/venv/bin/activate" ] || error "venv no encontrado. Ejecuta: bash backend/01_install_deps.sh"

source "$BACKEND_DIR/venv/bin/activate"
cd "$BACKEND_DIR"

if [ "$RESET" = true ]; then
    warn "⚠  Modo --reset: se eliminarán TODAS las tablas"
    read -rp "  ¿Confirmar? Escribe 'RESET' para continuar: " confirm
    [ "$confirm" != "RESET" ] && echo "  Cancelado." && exit 0
fi

log "Inicializando base de datos PostgreSQL..."
python3 - <<PYTHON
import sys, os
sys.path.insert(0, ".")

try:
    from app.database import Base, engine

    # Importar todos los modelos
    from app.modules.usuarios.models     import Usuario
    from app.modules.talleres.models     import Taller
    from app.modules.vehiculos.models    import Vehiculo
    from app.modules.incidentes.models   import Incidente, EvidenciaIncidente
    from app.modules.asignaciones.models import Asignacion, HistorialAsignacion
    from app.modules.bitacora.models     import Bitacora
    from app.modules.pagos.models        import Pago
    from app.modules.notificaciones.models import Notificacion

    reset = "${RESET}" == "true"
    if reset:
        print("  ⚠  Eliminando tablas existentes...")
        Base.metadata.drop_all(bind=engine)
        print("  ✅ Tablas eliminadas")

    print("  ⏳ Creando tablas...")
    Base.metadata.create_all(bind=engine)

    from sqlalchemy import inspect, text
    inspector = inspect(engine)
    tablas = inspector.get_table_names()
    print(f"\n  ✅ {len(tablas)} tabla(s) en la base de datos:")
    for t in sorted(tablas):
        cols = len(inspector.get_columns(t))
        print(f"     → {t:<35} ({cols} columnas)")

    # Verificar extensión uuid-ossp
    with engine.connect() as conn:
        conn.execute(text('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'))
        conn.commit()
    print("\n  ✅ Extensión uuid-ossp habilitada")

except Exception as e:
    print(f"  ❌ ERROR: {e}")
    import traceback; traceback.print_exc()
    sys.exit(1)
PYTHON

deactivate
echo ""
success "✅ Base de datos PostgreSQL inicializada"
