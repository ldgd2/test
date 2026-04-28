#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   DEPLOY MAESTRO — AutoWorks Bolivia                            ║
# ║   Ejecuta el despliegue completo de backend + frontend           ║
# ║   Uso: sudo bash deploy.sh                                       ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${CYAN}[DEPLOY]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
error()   { echo -e "${RED}[ ERROR]${NC} $*"; exit 1; }

# ── Configuración ────────────────────────────────────────────────────
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$DEPLOY_DIR")"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        🚀 AutoWorks Bolivia — Deploy Maestro         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
log "Directorio del proyecto: ${PROJECT_DIR}"
log "Iniciando despliegue completo..."
echo ""

# ── Verificar root ───────────────────────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
    error "Ejecuta este script como root: sudo bash deploy.sh"
fi

# ── Dar permisos a todos los scripts ─────────────────────────────────
log "Asignando permisos de ejecución a todos los scripts..."
find "$DEPLOY_DIR" -name "*.sh" -exec chmod +x {} \;
success "Permisos asignados"

# ══════════════════════════════════════════════════════════════════════
# BACKEND
# ══════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  🐍 BACKEND — FastAPI + Uvicorn                       ${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

log "Paso 1/4: Instalando dependencias del backend..."
bash "$DEPLOY_DIR/backend/01_install_deps.sh"

log "Paso 2/4: Inicializando base de datos..."
bash "$DEPLOY_DIR/backend/02_init_db.sh"

log "Paso 3/4: Creando servicio systemd del backend..."
bash "$DEPLOY_DIR/backend/04_create_service.sh"

log "Paso 4/4: Iniciando servicio backend..."
bash "$DEPLOY_DIR/backend/05_start_backend.sh"

# ══════════════════════════════════════════════════════════════════════
# FRONTEND
# ══════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  🅰️  FRONTEND — Angular SSR + Node.js                  ${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

log "Paso 1/3: Instalando dependencias del frontend..."
bash "$DEPLOY_DIR/frontend/01_install_deps.sh"

log "Paso 2/3: Compilando Angular en modo producción..."
bash "$DEPLOY_DIR/frontend/02_build.sh"

log "Paso 3/3: Creando e iniciando servicio systemd del frontend..."
bash "$DEPLOY_DIR/frontend/03_create_service.sh"
bash "$DEPLOY_DIR/frontend/04_start_frontend.sh"

# ══════════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ══════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              ✅ DESPLIEGUE COMPLETADO                 ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}●${NC} Backend  → http://185.214.134.23:8000"
echo -e "  ${GREEN}●${NC} Frontend → http://185.214.134.23:4000"
echo -e "  ${GREEN}●${NC} API Docs → http://185.214.134.23:8000/docs"
echo ""
echo -e "  Ver logs:"
echo -e "    sudo journalctl -u autoworks-backend  -f"
echo -e "    sudo journalctl -u autoworks-frontend -f"
echo ""
