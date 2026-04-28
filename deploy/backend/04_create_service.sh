#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   BACKEND — 04 Crear Servicio systemd                           ║
# ║   Instala autoworks-backend como servicio del sistema           ║
# ║   Uso: sudo bash backend/04_create_service.sh                   ║
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
SERVICE_NAME="autoworks-backend"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# ── Detectar usuario que ejecuta el proyecto ─────────────────────────
APP_USER="${SUDO_USER:-$(whoami)}"
APP_GROUP="$(id -gn "$APP_USER" 2>/dev/null || echo "$APP_USER")"

log "Creando servicio systemd: ${SERVICE_NAME}"
log "Directorio backend:  $BACKEND_DIR"
log "Usuario del servicio: $APP_USER:$APP_GROUP"
echo ""

# ── Verificar dependencias ────────────────────────────────────────────
[ -f "$BACKEND_DIR/.env" ]                      || error ".env no encontrado en $BACKEND_DIR"
[ -f "$BACKEND_DIR/venv/bin/uvicorn" ]          || error "Uvicorn no encontrado. Ejecuta primero: bash 01_install_deps.sh"
[ -f "$BACKEND_DIR/app/main.py" ]               || error "main.py no encontrado en $BACKEND_DIR/app/"

# ── Leer el puerto desde .env ─────────────────────────────────────────
API_PORT=$(grep -E '^API_PORT=' "$BACKEND_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d ' "' || echo "8000")
log "Puerto de la API: ${API_PORT}"

# ── Crear archivo de servicio systemd ────────────────────────────────
log "Escribiendo $SERVICE_FILE..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=AutoWorks Backend — FastAPI + Uvicorn
Documentation=https://fastapi.tiangolo.com
After=network.target
Wants=network-online.target

[Service]
Type=exec
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${BACKEND_DIR}
EnvironmentFile=${BACKEND_DIR}/.env
ExecStart=${BACKEND_DIR}/venv/bin/uvicorn app.main:app \\
    --host 0.0.0.0 \\
    --port ${API_PORT} \\
    --workers 2 \\
    --loop uvloop \\
    --http h11 \\
    --log-level info \\
    --access-log \\
    --no-use-colors
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=autoworks-backend

# Límites de recursos
LimitNOFILE=65536
TimeoutStartSec=30
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

success "Archivo de servicio creado: $SERVICE_FILE"

# ── Recargar systemd y habilitar servicio ─────────────────────────────
log "Recargando configuración de systemd..."
systemctl daemon-reload

log "Habilitando el servicio para inicio automático..."
systemctl enable "$SERVICE_NAME"

success "✅ Servicio '${SERVICE_NAME}' creado y habilitado"
echo ""
echo -e "  Comandos útiles:"
echo -e "    sudo systemctl start   ${SERVICE_NAME}"
echo -e "    sudo systemctl stop    ${SERVICE_NAME}"
echo -e "    sudo systemctl restart ${SERVICE_NAME}"
echo -e "    sudo systemctl status  ${SERVICE_NAME}"
echo -e "    sudo journalctl -u     ${SERVICE_NAME} -f"
