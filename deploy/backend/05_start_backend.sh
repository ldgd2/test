#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   BACKEND — 05 Iniciar / Reiniciar servicio                     ║
# ║   Uso: sudo bash backend/05_start_backend.sh                    ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${CYAN}[BACKEND]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }

SERVICE="autoworks-backend"

log "Iniciando/reiniciando servicio: $SERVICE"
systemctl restart "$SERVICE"
sleep 2
systemctl status "$SERVICE" --no-pager --lines=10

echo ""
success "✅ Backend corriendo en http://0.0.0.0:8000"
