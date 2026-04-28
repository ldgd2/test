#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   FRONTEND — 04 Iniciar / Reiniciar servicio                    ║
# ║   Uso: sudo bash frontend/04_start_frontend.sh                  ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${CYAN}[FRONTEND]${NC} $*"; }
success() { echo -e "${GREEN}[  OK  ]${NC} $*"; }

SERVICE="autoworks-frontend"

log "Iniciando/reiniciando servicio: $SERVICE"
systemctl restart "$SERVICE"
sleep 2
systemctl status "$SERVICE" --no-pager --lines=10

echo ""
success "✅ Frontend corriendo en http://0.0.0.0:4000"
