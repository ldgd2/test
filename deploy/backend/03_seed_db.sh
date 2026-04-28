#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   BACKEND — 03 Ejecutar Seeder                                  ║
# ║   Pobla la base de datos con datos de prueba                    ║
# ║   Uso: bash backend/03_seed_db.sh [--auto N]                    ║
# ║         --auto N  → modo no interactivo, N registros por tabla  ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${CYAN}[BACKEND]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
error()   { echo -e "${RED}[ ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BACKEND_DIR="$PROJECT_DIR/backend"

AUTO_MODE=false
AUTO_N=20

# ── Parsear argumentos ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            AUTO_MODE=true
            AUTO_N="${2:-20}"
            shift 2
            ;;
        --clean)
            CLEAN_FIRST=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

log "Ejecutando seeder de base de datos..."
log "Modo automático: $AUTO_MODE ${AUTO_MODE:+(N=$AUTO_N)}"
echo ""

# ── Activar entorno virtual ───────────────────────────────────────────
source "$BACKEND_DIR/venv/bin/activate"
cd "$BACKEND_DIR"

if [ "$AUTO_MODE" = true ]; then
    # ── Modo automático (no interactivo) ─────────────────────────────
    log "Ejecutando seeder en modo automático con $AUTO_N registros por tabla..."
    python3 - <<PYTHON
import sys
sys.path.insert(0, ".")

try:
    from app.database import SessionLocal
    from seeder import (
        seed_talleres, seed_usuarios, seed_vehiculos,
        seed_incidentes, seed_asignaciones, seed_historial
    )

    N = $AUTO_N
    db = SessionLocal()
    print(f"  🚀 Iniciando seeder automático con {N} registros por tabla...")

    talleres     = seed_talleres(db, n=max(5, N // 5))
    clientes, tecnicos, _ = seed_usuarios(db, talleres, n=N)
    vehiculos    = seed_vehiculos(db, clientes, n=N)
    incidentes   = seed_incidentes(db, clientes, vehiculos, n=N)
    asignaciones = seed_asignaciones(db, incidentes, talleres, tecnicos, n=N)
    seed_historial(db, asignaciones)

    db.close()
    print(f"\n  🎉 ¡Seeder completado! {N} registros por tabla.")

except Exception as e:
    print(f"  ❌ Error en el seeder: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON
else
    # ── Modo interactivo ──────────────────────────────────────────────
    log "Ejecutando seeder interactivo..."
    python3 seeder.py
fi

deactivate

echo ""
success "✅ Seeder ejecutado correctamente"
