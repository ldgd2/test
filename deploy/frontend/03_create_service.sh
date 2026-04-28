#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   FRONTEND — 03 Crear Servicio systemd                          ║
# ║   Instala autoworks-frontend como servicio del sistema          ║
# ║   Ejecuta Angular SSR vía Node.js en puerto 4000                ║
# ║   Uso: sudo bash frontend/03_create_service.sh                  ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${CYAN}[FRONTEND]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()    { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
error()   { echo -e "${RED}[ ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
FRONTEND_DIR="$PROJECT_DIR/frontend"
SERVICE_NAME="autoworks-frontend"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

APP_USER="${SUDO_USER:-$(whoami)}"
APP_GROUP="$(id -gn "$APP_USER" 2>/dev/null || echo "$APP_USER")"
NODE_BIN="$(which node)"
FRONTEND_PORT="4000"

log "Creando servicio systemd: ${SERVICE_NAME}"
log "Directorio frontend: $FRONTEND_DIR"
log "Usuario del servicio: $APP_USER:$APP_GROUP"
log "Node.js: $NODE_BIN"
echo ""

# ── Verificar que existe el build ─────────────────────────────────────
SSR_ENTRY="$FRONTEND_DIR/dist/frontend/server/server.mjs"
if [ ! -f "$SSR_ENTRY" ]; then
    error "Build no encontrado en $SSR_ENTRY — ejecuta primero: bash 02_build.sh"
fi
success "Build encontrado: $SSR_ENTRY"

# ── Crear archivo de servicio systemd ────────────────────────────────
log "Escribiendo $SERVICE_FILE..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=AutoWorks Frontend — Angular SSR con Node.js
Documentation=https://angular.dev/guide/ssr
After=network.target autoworks-backend.service
Wants=autoworks-backend.service

[Service]
Type=exec
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${FRONTEND_DIR}
Environment=NODE_ENV=production
Environment=PORT=${FRONTEND_PORT}
ExecStart=${NODE_BIN} ${SSR_ENTRY}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=autoworks-frontend

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

success "✅ Servicio '${SERVICE_NAME}' creado y habilitado en puerto ${FRONTEND_PORT}"
echo ""
echo -e "  Comandos útiles:"
echo -e "    sudo systemctl start   ${SERVICE_NAME}"
echo -e "    sudo systemctl stop    ${SERVICE_NAME}"
echo -e "    sudo systemctl restart ${SERVICE_NAME}"
echo -e "    sudo systemctl status  ${SERVICE_NAME}"
echo -e "    sudo journalctl -u     ${SERVICE_NAME} -f"
