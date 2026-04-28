#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   HERRAMIENTA — Actualización Rápida (Hot Deploy)               ║
# ║   Actualiza backend y/o frontend sin reinstalar todo            ║
# ║   Uso: sudo bash deploy/update.sh [--backend] [--frontend]      ║
# ║         (sin args → actualiza ambos)                            ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()     { echo -e "${CYAN}[UPDATE]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
error()   { echo -e "${RED}[ ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

UPDATE_BACKEND=false
UPDATE_FRONTEND=false

# Parsear args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backend|-b)   UPDATE_BACKEND=true;  shift ;;
        --frontend|-f)  UPDATE_FRONTEND=true; shift ;;
        *)              shift ;;
    esac
done

# Si no se especifica nada, actualizar ambos
if [ "$UPDATE_BACKEND" = false ] && [ "$UPDATE_FRONTEND" = false ]; then
    UPDATE_BACKEND=true
    UPDATE_FRONTEND=true
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        🔄 AutoWorks Bolivia — Actualización          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ══════════════════════════════════════════════════════════════════════
# BACKEND
# ══════════════════════════════════════════════════════════════════════
if [ "$UPDATE_BACKEND" = true ]; then
    log "━━ BACKEND ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    BACKEND_DIR="$PROJECT_DIR/backend"

    log "Actualizando dependencias Python..."
    source "$BACKEND_DIR/venv/bin/activate"
    pip install -r "$BACKEND_DIR/requirements.txt" -q
    deactivate
    success "Dependencias actualizadas"

    log "Verificando/actualizando tablas de BD..."
    bash "$SCRIPT_DIR/backend/02_init_db.sh"

    log "Reiniciando servicio backend..."
    systemctl restart autoworks-backend
    sleep 2
    if systemctl is-active --quiet autoworks-backend; then
        success "Backend reiniciado ✅"
    else
        error "El backend no pudo iniciarse. Revisa: journalctl -u autoworks-backend -n 30"
    fi
fi

# ══════════════════════════════════════════════════════════════════════
# FRONTEND
# ══════════════════════════════════════════════════════════════════════
if [ "$UPDATE_FRONTEND" = true ]; then
    log "━━ FRONTEND ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    FRONTEND_DIR="$PROJECT_DIR/frontend"

    log "Instalando/actualizando dependencias npm..."
    cd "$FRONTEND_DIR"
    npm install --legacy-peer-deps --silent

    log "Compilando Angular..."
    bash "$SCRIPT_DIR/frontend/02_build.sh"

    log "Reiniciando servicio frontend..."
    systemctl restart autoworks-frontend
    sleep 2
    if systemctl is-active --quiet autoworks-frontend; then
        success "Frontend reiniciado ✅"
    else
        error "El frontend no pudo iniciarse. Revisa: journalctl -u autoworks-frontend -n 30"
    fi
fi

# ── Resumen ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}✅ Actualización completada${NC}"
echo ""
[ "$UPDATE_BACKEND"  = true ] && echo -e "  ${GREEN}●${NC} Backend  → http://185.214.134.23:8000"
[ "$UPDATE_FRONTEND" = true ] && echo -e "  ${GREEN}●${NC} Frontend → http://185.214.134.23:4000"
echo ""
